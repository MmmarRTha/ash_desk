defmodule AshDeskWeb.ConversationRealtime do
  defmacro __using__(_opts) do
    quote do
      import AshDeskWeb.Helpers

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
      def handle_info(:load_presence, socket) do
        {:noreply,
         assign(socket, :online_users, AshDeskWeb.Presence.list(socket.assigns.presence_topic))}
      end

      @impl true
      def handle_info(%{event: "presence_diff"}, socket) do
        {:noreply,
         assign(socket, :online_users, AshDeskWeb.Presence.list(socket.assigns.presence_topic))}
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

          AshDeskWeb.TypingIndicator.unsubscribe(socket)

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
        AshDeskWeb.TypingIndicator.subscribe(socket)

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
          socket.assigns[:presence_topic],
          socket.assigns[:typing_topic]
        ]
      end
    end
  end
end
