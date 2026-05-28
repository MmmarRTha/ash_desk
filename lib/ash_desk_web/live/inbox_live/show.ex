defmodule AshDeskWeb.InboxLive.Show do
  use AshDeskWeb, :live_view

  on_mount {AshDeskWeb.LiveUserAuth, :live_user_required}
  on_mount {AshDeskWeb.LiveUserAuth, :current_user}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    current_user = socket.assigns.current_user
    conversation_id = params["id"]

    case AshDesk.Organizations.list_organizations(actor: current_user) do
      {:ok, [org | _]} ->
        case AshDesk.Support.get_conversation_by_id(conversation_id,
               actor: current_user,
               tenant: org.id
             ) do
          {:ok, conversation} ->
            {:ok, all_messages} =
              AshDesk.Support.list_messages(
                actor: current_user,
                load: [:sender],
                authorize?: false
              )

            messages = Enum.filter(all_messages, &(&1.conversation_id == conversation_id))
            message_form = to_form(%{"body" => ""})

            {:noreply,
             socket
             |> assign(:org, org)
             |> assign(:conversation, conversation)
             |> assign(:messages, messages)
             |> assign(:message_form, message_form)}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Conversation not found")
             |> push_navigate(to: ~p"/inbox")}
        end

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "No organization found")
         |> push_navigate(to: ~p"/inbox")}
    end
  end

  @impl true
  def handle_event("send_message", %{"body" => body}, socket) do
    current_user = socket.assigns.current_user
    conversation = socket.assigns.conversation

    case AshDesk.Support.create_message(
           %{body: body, conversation_id: conversation.id, sender_id: current_user.id},
           actor: current_user
         ) do
      {:ok, _message} ->
        {:ok, all_messages} =
          AshDesk.Support.list_messages(actor: current_user, load: [:sender], authorize?: false)

        messages = Enum.filter(all_messages, &(&1.conversation_id == conversation.id))

        {:noreply,
         socket
         |> assign(:messages, messages)
         |> assign(:message_form, to_form(%{"body" => ""}))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to send message: #{inspect(reason)}")}
    end
  end
end
