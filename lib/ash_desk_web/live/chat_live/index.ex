defmodule AshDeskWeb.ChatLive.Index do
  use AshDeskWeb, :live_view

  on_mount {AshDeskWeb.LiveUserAuth, :live_user_required}
  on_mount {AshDeskWeb.LiveUserAuth, :current_user}

  import AshDeskWeb.Helpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Support")}
  end

  @impl true
  def handle_params(%{"org_slug" => slug}, _uri, socket) do
    current_user = socket.assigns.current_user

    org = AshDesk.Organizations.get_organization_by_slug!(slug, actor: current_user)

    socket =
      socket
      |> assign(:org, org)
      |> stream(:conversations, [], reset: true)

    socket =
      if connected?(socket) do
        topic = "org:conversations:#{org.id}"
        Phoenix.PubSub.subscribe(AshDesk.PubSub, topic)
        assign(socket, :conversation_topic, topic)
      else
        assign(socket, :conversation_topic, nil)
      end

    socket =
      if connected?(socket) do
        start_async(socket, :load_customer_conversations, fn ->
          {:ok, conversations} =
            AshDesk.Support.list_conversations_for_customer(current_user.id,
              actor: current_user,
              tenant: org.id
            )

          conversations
        end)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_user}>
      <div class="bg-base-200/80 rounded-box border border-base-300 p-6">
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
            <.link navigate={~p"/#{@org.slug}/chat/#{conversation.id}"} class="block p-4">
              <div class="flex items-center gap-3">
                <div class="flex items-center justify-center shrink-0 bg-primary text-primary-content rounded-full w-8 h-8">
                  <.icon name="hero-chat-bubble-left-ellipsis" class="size-5" />
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
  def handle_event("start_conversation", %{"subject" => subject}, socket) do
    current_user = socket.assigns.current_user
    org = socket.assigns.org

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
         |> push_navigate(to: ~p"/#{org.slug}/chat/#{conversation.id}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start conversation: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_async(:load_customer_conversations, {:ok, conversations}, socket) do
    {:noreply, stream(socket, :conversations, conversations, reset: true)}
  end

  def handle_async(:load_customer_conversations, {:exit, reason}, socket) do
    require Logger
    Logger.error("load_customer_conversations failed: #{inspect(reason)}")
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
end
