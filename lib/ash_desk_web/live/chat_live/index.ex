defmodule AshDeskWeb.ChatLive.Index do
  use AshDeskWeb, :live_view

  on_mount {AshDeskWeb.LiveUserAuth, :live_user_required}
  on_mount {AshDeskWeb.LiveUserAuth, :current_user}

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, :page_title, "Support")

    socket =
      if connected?(socket) do
        current_user = socket.assigns.current_user

        socket
        |> assign(:org, nil)
        |> stream(:conversations, [])
        |> start_async(:fetch_portal, fn -> fetch_portal_data(current_user) end)
      else
        socket
        |> assign(:org, nil)
        |> stream(:conversations, [])
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_user}>
      <div class="max-w-2xl mx-auto">
        <h1 class="text-2xl font-bold mb-6">Support</h1>

        <div class="card bg-base-200 border border-base-300 p-6 mb-8">
          <h2 class="font-semibold mb-3">Start a new conversation</h2>
          <form phx-submit="start_conversation" class="flex gap-2">
            <input
              type="text"
              name="subject"
              placeholder="How can we help you?"
              class="input input-bordered flex-1"
            />
            <button class="btn btn-primary">Send</button>
          </form>
        </div>

        <h2 class="font-semibold mb-3">Your conversations</h2>

        <div id="conversations" phx-update="stream">
          <div id="conversations-empty" class="hidden only:block text-center py-12">
            <.icon name="hero-chat-bubble-left-right" class="size-12 opacity-30 mx-auto mb-3" />
            <p class="opacity-50">No conversations yet. Start one above!</p>
          </div>
          <div
            :for={{id, conversation} <- @streams.conversations}
            id={id}
            class="card bg-base-200 hover:bg-base-300 transition-colors cursor-pointer mb-3 border border-base-300 hover:border-primary/30"
          >
            <.link navigate={~p"/chat/#{conversation.id}"} class="block p-4">
              <div class="flex items-center gap-3">
                <div class="avatar placeholder">
                  <div class="bg-primary text-primary-content rounded-full w-10">
                    <span class="text-sm font-bold">S</span>
                  </div>
                </div>
                <div class="flex-1 min-w-0">
                  <div class="flex justify-between items-center">
                    <span class="font-medium truncate">
                      {conversation.subject || "No subject"}
                    </span>
                    <span class={[
                      "badge badge-sm shrink-0",
                      conversation.status == :open && "badge-success",
                      conversation.status == :pending && "badge-warning",
                      conversation.status == :resolved && "badge-ghost"
                    ]}>
                      {conversation.status}
                    </span>
                  </div>
                  <div class="text-sm opacity-50 mt-1">
                    {relative_time(conversation.created_at)}
                  </div>
                </div>
                <.icon name="hero-chevron-right" class="size-5 opacity-30" />
              </div>
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_conversation", %{"subject" => subject}, socket) do
    current_user = socket.assigns.current_user
    org = socket.assigns.org

    if org do
      case AshDesk.Support.create_conversation_by_customer(
             subject,
             %{organization_id: org.id},
             actor: current_user,
             tenant: org.id
           ) do
        {:ok, conversation} ->
          {:noreply,
           socket
           |> put_flash(:info, "Conversation started!")
           |> push_navigate(to: ~p"/chat/#{conversation.id}")}

        {:error, reason} ->
          {:noreply,
           put_flash(socket, :error, "Failed to start conversation: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "No organization found")}
    end
  end

  @impl true
  def handle_async(:fetch_portal, {:ok, %{org: org, conversations: conversations}}, socket) do
    socket =
      socket
      |> assign(:org, org)
      |> stream(:conversations, conversations, reset: true)

    socket =
      if connected?(socket) and org do
        topic = "org:conversations:#{org.id}"
        Phoenix.PubSub.subscribe(AshDesk.PubSub, topic)
        assign(socket, :conversation_topic, topic)
      else
        assign(socket, :conversation_topic, nil)
      end

    {:noreply, socket}
  end

  def handle_async(:fetch_portal, {:exit, reason}, socket) do
    require Logger
    Logger.error("fetch_portal failed: #{inspect(reason)}")
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "org:conversations:" <> _,
          event: "create",
          payload: %Ash.Notifier.Notification{data: conversation}
        },
        socket
      ) do
    conversation =
      case Ash.load(conversation, [:assigned_agent], actor: socket.assigns.current_user) do
        {:ok, loaded} -> loaded
        _ -> conversation
      end

    {:noreply, stream_insert(socket, :conversations, conversation, at: 0)}
  end

  defp fetch_portal_data(current_user) do
    case AshDesk.Organizations.list_organizations(actor: current_user) do
      {:ok, [org | _]} ->
        load_customer_conversations(current_user, org)

      _ ->
        case AshDesk.Organizations.list_organizations(actor: current_user, authorize?: false) do
          {:ok, [org | _]} ->
            AshDesk.Organizations.create_membership(
              %{user_id: current_user.id, organization_id: org.id, role: :customer},
              actor: current_user,
              tenant: org.id
            )

            load_customer_conversations(current_user, org)

          _ ->
            %{org: nil, conversations: []}
        end
    end
  end

  defp load_customer_conversations(current_user, org) do
    conversations =
      case AshDesk.Support.list_conversations_for_customer(
             current_user.id,
             actor: current_user,
             tenant: org.id
           ) do
        {:ok, convs} -> convs
        _ -> []
      end

    %{org: org, conversations: conversations}
  end

  defp relative_time(%DateTime{} = datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} min ago"
      diff < 86400 -> "#{div(diff, 3600)} hour ago"
      diff < 604_800 -> "#{div(diff, 86400)} day ago"
      diff < 2_592_000 -> "#{div(diff, 86400)} days ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end

  defp relative_time(_), do: ""
end
