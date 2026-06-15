defmodule AshDeskWeb.TypingIndicator do
  use Phoenix.Component

  defmacro __using__(_opts) do
    quote do
      def handle_event("typing_start", _params, socket) do
        current_user = socket.assigns.current_user

        AshDesk.Support.TypingServer.typing_start(
          socket.assigns.conversation_id,
          current_user.id,
          current_user.email
        )

        {:noreply, socket}
      end

      def handle_event("stopped_typing", _params, socket) do
        current_user = socket.assigns.current_user

        AshDesk.Support.TypingServer.stopped_typing(
          socket.assigns.conversation_id,
          current_user.id
        )

        {:noreply, socket}
      end

      def handle_info({:typing, :start, user_id, email}, socket) do
        if user_id != socket.assigns.current_user.id do
          {:noreply,
           assign(
             socket,
             :typing_users,
             Map.put(socket.assigns.typing_users, user_id, %{email: email})
           )}
        else
          {:noreply, socket}
        end
      end

      def handle_info({:typing, :stop, user_id, _email}, socket) do
        {:noreply, update(socket, :typing_users, &Map.delete(&1, user_id))}
      end
    end
  end

  def setup_typing(socket, conversation_id) do
    socket
    |> assign(:conversation_id, conversation_id)
    |> assign(:typing_topic, "conversation:typing:#{conversation_id}")
    |> assign(:typing_users, %{})
  end

  def subscribe(socket) do
    Phoenix.PubSub.subscribe(AshDesk.PubSub, socket.assigns.typing_topic)
    socket
  end

  def unsubscribe(socket) do
    if topic = socket.assigns[:typing_topic] do
      Phoenix.PubSub.unsubscribe(AshDesk.PubSub, topic)
    end

    socket
  end

  def typing_text(typing_users) do
    names =
      typing_users
      |> Enum.map(fn {_, %{email: email}} ->
        email |> to_string() |> String.split("@") |> hd()
      end)

    case names do
      [] ->
        ""

      [n] ->
        "#{n} is typing..."

      [a, b] ->
        "#{a} and #{b} are typing..."

      [a, b | rest] ->
        "#{a}, #{b}, and #{length(rest)} other#{if length(rest) > 1, do: "s"} are typing..."
    end
  end
end
