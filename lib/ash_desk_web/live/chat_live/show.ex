defmodule AshDeskWeb.ChatLive.Show do
  use AshDeskWeb, :live_view
  use AshDeskWeb.TypingIndicator
  use AshDeskWeb.ConversationRealtime

  import AshDeskWeb.ChatComponents

  on_mount {AshDeskWeb.LiveUserAuth, :live_user_required}
  on_mount {AshDeskWeb.LiveUserAuth, :current_user}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    case AshDesk.Organizations.list_organizations(actor: current_user) do
      {:ok, [org | _]} ->
        {:ok, assign(socket, :org, org)}

      _ ->
        {:ok,
         socket
         |> assign(:org, nil)
         |> assign(:org_missing, true)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_user}>
      <.link
        navigate={~p"/chat"}
        class="text-sm opacity-70 hover:opacity-100 inline-flex items-center gap-1 mb-4"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back to conversations
      </.link>

      <div class="max-w-2xl mx-auto">
        <div class="mb-6">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold">{@conversation.subject || "Conversation"}</h1>
              <.status_badge status={@conversation.status} />
            </div>
            <.presence_indicators users={@online_users} />
          </div>
        </div>

        <div id="messages" phx-update="stream" class="space-y-4 mb-4 min-h-[200px]">
          <.empty_state
            :if={@streams.messages == []}
            title="No messages yet"
            message="Send the first message!"
          />
          <div
            :for={{id, message} <- @streams.messages}
            id={id}
            style="--stagger-index: 0"
          >
            <.message_bubble
              message={message}
              current_user={@current_user}
            />
          </div>
        </div>

        <.typing_indicator users={@typing_users} />
        <.message_input form={@message_form} input_id={@message_input_id} />
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(_params, _uri, %{assigns: %{org_missing: true}} = socket) do
    {:noreply,
     socket
     |> put_flash(:error, "No organization found")
     |> push_navigate(to: ~p"/chat")}
  end

  @impl true
  def handle_params(%{"id" => conversation_id}, _uri, socket) do
    case socket.assigns[:org] do
      nil ->
        {:noreply, socket}

      org ->
        current_user = socket.assigns.current_user

        case AshDesk.Support.get_conversation_by_id(
               conversation_id,
               actor: current_user,
               tenant: org.id
             ) do
          {:ok, conversation} ->
            message_topic = "conversation:messages:#{conversation_id}"
            meta_topic = "conversation:meta:#{conversation_id}"
            presence_topic = "conversation:#{conversation_id}"

            socket =
              if connected?(socket) do
                socket
                |> cancel_async(:fetch_messages)
                |> leave_conversation(current_user.id)
              else
                socket
              end

            socket =
              socket
              |> assign(:page_title, conversation.subject || "Conversation")
              |> assign(:conversation, conversation)
              |> assign(:message_topic, message_topic)
              |> assign(:meta_topic, meta_topic)
              |> assign(:presence_topic, presence_topic)
              |> AshDeskWeb.TypingIndicator.setup_typing(conversation_id)
              |> assign(:online_users, %{})
              |> assign(:message_input_id, 0)
              |> assign(:message_form, to_form(%{"body" => ""}, id: "send-message-form"))
              |> stream(:messages, [], reset: true)

            socket =
              if connected?(socket) do
                join_conversation(
                  socket,
                  current_user,
                  message_topic,
                  meta_topic,
                  presence_topic,
                  conversation_id,
                  org
                )
              else
                socket
              end

            {:noreply, socket}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Conversation not found")
             |> push_navigate(to: ~p"/chat")}
        end
    end
  end

  @impl true
  def handle_async(
        :fetch_messages,
        {:ok, {:ok, %{messages: messages}}},
        socket
      ) do
    {:noreply, stream(socket, :messages, messages, reset: true)}
  end

  @impl true
  def handle_async(:fetch_messages, {:exit, reason}, socket) do
    require Logger
    Logger.error("fetch_messages crashed: #{inspect(reason)}")

    {:noreply, put_flash(socket, :error, "Failed to load conversation. Please try again.")}
  end

  defp fetch_conversation_data(conversation_id, current_user, org) do
    with {:ok, messages} <-
           AshDesk.Support.list_messages_for_conversation(
             %{conversation_id: conversation_id},
             actor: current_user
           ),
         {:ok, memberships} <-
           AshDesk.Organizations.list_memberships(
             actor: current_user,
             tenant: org.id,
             load: [:user]
           ) do
      {:ok,
       %{
         messages: messages,
         agents: Enum.map(memberships, & &1.user),
         is_admin: Enum.any?(memberships, &(&1.user_id == current_user.id and &1.role == :admin))
       }}
    end
  end
end
