defmodule AshDeskWeb.InboxLive.Show do
  use AshDeskWeb, :live_view

  on_mount {AshDeskWeb.LiveUserAuth, :live_user_required}
  on_mount {AshDeskWeb.LiveUserAuth, :current_user}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    socket =
      case AshDesk.Organizations.list_organizations(actor: current_user) do
        {:ok, [org | _]} ->
          assign(socket, :org, org)

        _ ->
          socket
          |> put_flash(:error, "No organization found")
          |> push_navigate(to: ~p"/inbox")
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_user}>
      <.link navigate={~p"/inbox"} class="text-sm opacity-70 hover:opacity-100">
        ← Back to Inbox
      </.link>

      <h1 class="text-2xl font-bold mt-4 mb-6">{@org.name} — Conversation</h1>

      <div id="messages" phx-update="stream" class="space-y-3 mb-8">
        <div id="messages-empty" class="hidden only:block text-center py-8 opacity-50">
          No messages yet. Send the first message!
        </div>
        <div :for={{id, message} <- @streams.messages} id={id} class="chat">
          <div class="chat-bubble">
            <div class="flex justify-between items-center">
              <div class="text-xs font-bold">
                {if message.sender.email == @current_user.email, do: "Me", else: message.sender.email}
              </div>
              <div class="text-xs opacity-50">
                {relative_time(message.created_at)}
              </div>
            </div>
            <p>{message.body}</p>
          </div>
        </div>
      </div>

      <.form for={@message_form} id="send-message-form" phx-submit="send_message">
        <.input field={@message_form[:body]} type="textarea" placeholder="Type your message..." />
        <.button class="mt-2">Send</.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(%{"id" => conversation_id}, _uri, socket) do
    current_user = socket.assigns.current_user
    org = socket.assigns.org

    case AshDesk.Support.get_conversation_by_id(conversation_id,
           actor: current_user,
           tenant: org.id
         ) do
      {:ok, conversation} ->
        socket =
          socket
          |> assign(:conversation, conversation)
          |> assign(:message_form, to_form(%{"body" => ""}))
          |> stream(:messages, [])

        socket =
          if connected?(socket) do
            start_async(socket, :fetch_messages, fn ->
              {:ok, messages} =
                AshDesk.Support.list_messages_for_conversation(
                  %{conversation_id: conversation_id},
                  actor: current_user
                )

              %{messages: messages}
            end)
          else
            socket
          end

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Conversation not found")
         |> push_navigate(to: ~p"/inbox")}
    end
  end

  @impl true
  def handle_event("send_message", %{"body" => body}, socket) do
    current_user = socket.assigns.current_user
    conversation = socket.assigns.conversation

    case AshDesk.Support.create_message(
           %{body: body, conversation_id: conversation.id},
           actor: current_user
         ) do
      {:ok, message} ->
        {:ok, message} =
          Ash.load(message, [:sender],
            actor: current_user,
            authorize?: false
          )

        {:noreply,
         socket
         |> stream_insert(:messages, message)
         |> assign(:message_form, to_form(%{"body" => ""}))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to send message: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_async(:fetch_messages, {:ok, %{messages: messages}}, socket) do
    {:noreply, stream(socket, :messages, messages, reset: true)}
  end

  def handle_async(:fetch_messages, {:exit, _reason}, socket) do
    {:noreply, socket}
  end

  defp relative_time(%DateTime{} = datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> " just now"
      diff < 3600 -> " #{div(diff, 60)} min ago"
      diff < 86400 -> " #{div(diff, 3600)} hour ago"
      diff < 604_800 -> " #{div(diff, 86400)} day ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end

  defp relative_time(_), do: ""
end
