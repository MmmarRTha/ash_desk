defmodule AshDeskWeb.ChatLive.Show do
  use AshDeskWeb, :live_view

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
              <span class={[
                "badge mt-1",
                @conversation.status == :open && "badge-success",
                @conversation.status == :pending && "badge-warning",
                @conversation.status == :resolved && "badge-ghost"
              ]}>
                {@conversation.status}
              </span>
            </div>

            <div :if={@online_users != %{}} class="flex items-center gap-2">
              <div class="flex -space-x-2">
                <div
                  :for={{_user_id, user} <- Enum.take(@online_users, 3)}
                  class="relative"
                >
                  <div class="avatar placeholder">
                    <div class="bg-success text-success-content rounded-full w-8 ring-2 ring-base-100">
                      <span class="text-xs">
                        {String.upcase(String.first(List.first(user.metas).email) || "U")}
                      </span>
                    </div>
                  </div>
                  <span class="absolute bottom-0 right-0 size-2.5 bg-success rounded-full ring-2 ring-base-100">
                  </span>
                </div>
              </div>
              <span :if={map_size(@online_users) > 3} class="text-xs text-success font-medium">
                +{map_size(@online_users) - 3} online
              </span>
              <span :if={map_size(@online_users) <= 3} class="text-xs text-success font-medium">
                {map_size(@online_users)} online
              </span>
            </div>
          </div>
        </div>

        <div id="messages" phx-update="stream" class="space-y-4 mb-4 min-h-[200px]">
          <div id="messages-empty" class="hidden only:block text-center py-12">
            <.icon name="hero-chat-bubble-left-right" class="size-12 opacity-30 mx-auto mb-3" />
            <p class="opacity-50">No messages yet. Send the first message!</p>
          </div>
          <div
            :for={{id, message} <- @streams.messages}
            id={id}
            class={[
              "chat",
              message.sender_id == @current_user.id && "chat-end",
              message.sender_id != @current_user.id && "chat-start"
            ]}
          >
            <div class="chat-header mb-1">
              <span class="text-xs font-bold">
                {if message.sender_id == @current_user.id, do: "You", else: "Support"}
              </span>
              <time class="text-xs opacity-50">{relative_time(message.created_at)}</time>
            </div>
            <div class={[
              "chat-bubble max-w-[80%]",
              message.sender_id == @current_user.id && "chat-bubble-primary text-primary-content",
              message.sender_id != @current_user.id && "chat-bubble-base-300"
            ]}>
              {message.body}
            </div>
          </div>
        </div>

        <.form
          for={@message_form}
          id="send-message-form"
          phx-submit="send_message"
          class="sticky bottom-0 bg-base-100 pt-4 pb-2 border-t border-base-300"
        >
          <div class="flex gap-2 items-end">
            <.input
              id={"message-body-#{@message_input_id}"}
              field={@message_form[:body]}
              type="textarea"
              placeholder="Type your message..."
              class="flex-1"
            />
            <.button class="btn btn-primary btn-circle shrink-0" phx-disable-with="...">
              <.icon name="hero-paper-airplane" class="size-5" />
            </.button>
          </div>
        </.form>
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
  def terminate(_reason, socket) do
    user_id = socket.assigns[:current_user] && socket.assigns.current_user.id
    leave_conversation(socket, user_id)
    :ok
  end

  @impl true
  def handle_event("send_message", %{"body" => body}, socket) do
    current_user = socket.assigns.current_user
    conversation = socket.assigns.conversation

    case AshDesk.Support.create_message(%{body: body, conversation_id: conversation.id},
           actor: current_user
         ) do
      {:ok, message} ->
        {:ok, message} = Ash.load(message, [:sender], actor: current_user)

        {:noreply,
         socket
         |> stream_insert(:messages, message, at: 0)
         |> assign(:message_form, to_form(%{"body" => ""}, id: "send-message-form"))
         |> update(:message_input_id, &(&1 + 1))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to send message: #{inspect(reason)}")}
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

  @impl true
  def handle_info(:load_presence, socket) do
    {:noreply,
     assign(
       socket,
       :online_users,
       AshDeskWeb.Presence.list(socket.assigns.presence_topic)
     )}
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply,
     assign(
       socket,
       :online_users,
       AshDeskWeb.Presence.list(socket.assigns.presence_topic)
     )}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "conversation:messages:" <> _,
          event: "create",
          payload: %Ash.Notifier.Notification{data: message}
        },
        socket
      ) do
    {:noreply, stream_insert(socket, :messages, message, at: 0)}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "conversation:meta:" <> _,
          event: "update",
          payload: %Ash.Notifier.Notification{data: conversation}
        },
        socket
      ) do
    {:noreply, assign(socket, :conversation, conversation)}
  end

  defp leave_conversation(socket, user_id) do
    if connected?(socket) do
      for topic <- conversation_topics(socket), is_binary(topic) do
        Phoenix.PubSub.unsubscribe(AshDesk.PubSub, topic)
      end

      case socket.assigns[:presence_topic] do
        topic when is_binary(topic) and not is_nil(user_id) ->
          AshDeskWeb.Presence.untrack(self(), topic, user_id)

        _ ->
          :ok
      end
    end

    socket
  end

  defp join_conversation(
         socket,
         current_user,
         message_topic,
         meta_topic,
         presence_topic,
         conversation_id,
         org
       ) do
    Phoenix.PubSub.subscribe(AshDesk.PubSub, message_topic)
    Phoenix.PubSub.subscribe(AshDesk.PubSub, meta_topic)
    Phoenix.PubSub.subscribe(AshDesk.PubSub, presence_topic)

    AshDeskWeb.Presence.track(
      self(),
      presence_topic,
      current_user.id,
      %{
        email: to_string(current_user.email),
        joined_at: System.system_time(:second)
      }
    )

    send(self(), :load_presence)

    start_async(socket, :fetch_messages, fn ->
      fetch_conversation_data(conversation_id, current_user, org)
    end)
  end

  defp conversation_topics(socket) do
    [
      socket.assigns[:message_topic],
      socket.assigns[:meta_topic],
      socket.assigns[:presence_topic]
    ]
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
