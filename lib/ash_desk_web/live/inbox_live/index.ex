defmodule AshDeskWeb.InboxLive.Index do
  use AshDeskWeb, :live_view

  on_mount {AshDeskWeb.LiveUserAuth, :live_user_required}
  on_mount {AshDeskWeb.LiveUserAuth, :current_user}

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, :page_title, "Inbox")

    socket =
      if connected?(socket) do
        current_user = socket.assigns.current_user

        socket
        |> assign(:org, nil)
        |> stream(:conversations, [])
        |> start_async(:fetch_inbox, fn -> fetch_inbox_data(current_user) end)
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
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold">
          {if @org, do: "#{@org.name} — Inbox", else: "Loading..."}
        </h1>
      </div>

      <div id="conversations" phx-update="stream">
        <div id="conversations-empty" class="hidden only:block text-center py-16">
          <.icon name="hero-chat-bubble-left-right" class="size-16 opacity-30 mx-auto mb-4" />
          <h3 class="text-lg font-medium opacity-70">No conversations yet</h3>
          <p class="text-sm opacity-50 mt-1">
            Conversations will appear here when customers reach out.
          </p>
        </div>
        <div
          :for={{id, conversation} <- @streams.conversations}
          id={id}
          class="card bg-base-200 hover:bg-base-300 transition-colors cursor-pointer mb-3 border border-base-300 hover:border-primary/30"
        >
          <.link navigate={~p"/inbox/#{conversation.id}"} class="block p-4">
            <div class="flex items-center gap-3">
              <div class="avatar placeholder">
                <div class="bg-primary text-primary-content rounded-full w-10">
                  <span class="text-sm">
                    {String.upcase(
                      String.first(
                        to_string(
                          (conversation.assigned_agent && conversation.assigned_agent.email) || "U"
                        )
                      )
                    )}
                  </span>
                </div>
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex justify-between items-center">
                  <span class="font-medium truncate">
                    {(conversation.assigned_agent && conversation.assigned_agent.email) ||
                      "Unassigned"}
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
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_async(:fetch_inbox, {:ok, %{org: org, conversations: conversations}}, socket) do
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

  def handle_async(:fetch_inbox, {:exit, reason}, socket) do
    require Logger
    Logger.error("fetch_inbox failed: #{inspect(reason)}")
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

  defp fetch_inbox_data(current_user) do
    case AshDesk.Organizations.list_organizations(actor: current_user) do
      {:ok, [org | _]} ->
        {:ok, memberships} =
          AshDesk.Organizations.list_memberships(
            actor: current_user,
            tenant: org.id,
            load: [:user]
          )

        current_membership = Enum.find(memberships, &(&1.user_id == current_user.id))
        is_admin = current_membership && current_membership.role == :admin

        conversations =
          if is_admin do
            case AshDesk.Support.list_conversations(actor: current_user, tenant: org.id) do
              {:ok, convs} ->
                {:ok, loaded} = Ash.load(convs, [:assigned_agent], actor: current_user)
                loaded

              {:error, _} ->
                []
            end
          else
            case AshDesk.Support.list_conversations_for_agent(
                   %{agent_id: current_user.id},
                   actor: current_user,
                   tenant: org.id
                 ) do
              {:ok, convs} ->
                convs

              {:error, _} ->
                []
            end
          end

        %{org: org, conversations: conversations}

      _ ->
        %{org: nil, conversations: []}
    end
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
