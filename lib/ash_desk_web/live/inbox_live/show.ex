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
      <.link
        navigate={~p"/inbox"}
        class="text-sm opacity-70 hover:opacity-100 inline-flex items-center gap-1 mb-4"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back to Inbox
      </.link>

      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold">{@org.name}</h1>
          <p class="text-sm opacity-50">Conversation</p>
        </div>

        <div class="flex items-center gap-4">
          <%!-- Online presence indicator --%>
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

          <div :if={@is_admin} class="flex items-center gap-2">
            <.icon name="hero-user-group" class="size-4 opacity-70" />
            <form id="assign-agent-form" phx-change="assign_agent">
              <select name="agent_id" class="select select-bordered select-sm select-primary">
                <option value="">Unassigned</option>
                <option
                  :for={agent <- @agents}
                  value={agent.id}
                  selected={agent.id == @conversation.assigned_agent_id}
                >
                  {agent.email}
                </option>
              </select>
            </form>
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
            message.sender.email == @current_user.email && "chat-end",
            message.sender.email != @current_user.email && "chat-start"
          ]}
        >
          <div class="chat-header mb-1">
            <span class="text-xs font-bold">
              {if message.sender.email == @current_user.email, do: "Me", else: message.sender.email}
            </span>
            <time class="text-xs opacity-50">{relative_time(message.created_at)}</time>
          </div>
          <div class={[
            "chat-bubble max-w-[80%]",
            message.sender.email == @current_user.email && "chat-bubble-primary text-primary-content",
            message.sender.email != @current_user.email && "chat-bubble-base-300"
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
            id={"message-body-#{Enum.count(@streams.messages)}"}
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
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(%{"id" => conversation_id}, _uri, socket) do
    current_user = socket.assigns.current_user
    org = socket.assigns.org

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
          socket
          |> assign(:conversation, conversation)
          |> assign(:agents, [])
          |> assign(:is_admin, false)
          |> assign(:message_topic, message_topic)
          |> assign(:meta_topic, meta_topic)
          |> assign(:presence_topic, presence_topic)
          |> assign(:online_users, %{})
          |> assign(
            :message_form,
            to_form(%{"body" => ""}, id: "send-message-form")
          )
          |> stream(:messages, [])

        socket =
          if connected?(socket) do
            Phoenix.PubSub.subscribe(
              AshDesk.PubSub,
              message_topic
            )

            Phoenix.PubSub.subscribe(
              AshDesk.PubSub,
              meta_topic
            )

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
              fetch_conversation_data(
                conversation_id,
                current_user,
                org
              )
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

    case AshDesk.Support.create_message(%{body: body, conversation_id: conversation.id},
           actor: current_user
         ) do
      {:ok, message} ->
        {:ok, message} = Ash.load(message, [:sender], actor: current_user)

        {:noreply,
         socket
         |> stream_insert(:messages, message)
         |> assign(:message_form, to_form(%{"body" => ""}, id: "send-message-form"))}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Failed to send message: #{inspect(reason)}"
         )}
    end
  end

  @impl true
  def handle_event("assign_agent", %{"agent_id" => agent_id}, socket) do
    agent_id = if agent_id == "", do: nil, else: agent_id

    case AshDesk.Support.update_conversation(
           socket.assigns.conversation,
           %{assigned_agent_id: agent_id},
           actor: socket.assigns.current_user,
           tenant: socket.assigns.org.id
         ) do
      {:ok, conversation} ->
        {:noreply, assign(socket, :conversation, conversation)}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Failed to assign: #{inspect(reason)}"
         )}
    end
  end

  @impl true
  def handle_async(
        :fetch_messages,
        {:ok, %{messages: messages, agents: agents, is_admin: is_admin}},
        socket
      ) do
    {:noreply,
     socket
     |> stream(:messages, messages, reset: true)
     |> assign(:agents, agents)
     |> assign(:is_admin, is_admin)}
  end

  @impl true
  def handle_async(:fetch_messages, {:exit, _reason}, socket) do
    {:noreply, socket}
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
    {:noreply, stream_insert(socket, :messages, message)}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "conversation:meta:" <> _,
          event: "update",
          payload: %{conversation: conversation}
        },
        socket
      ) do
    {:noreply, assign(socket, :conversation, conversation)}
  end

  defp fetch_conversation_data(conversation_id, current_user, org) do
    {:ok, messages} =
      AshDesk.Support.list_messages_for_conversation(
        %{conversation_id: conversation_id},
        actor: current_user
      )

    {:ok, memberships} =
      AshDesk.Organizations.list_memberships(
        actor: current_user,
        tenant: org.id,
        load: [:user]
      )

    %{
      messages: messages,
      agents: Enum.map(memberships, & &1.user),
      is_admin: Enum.any?(memberships, &(&1.user_id == current_user.id and &1.role == :admin))
    }
  end

  defp relative_time(%DateTime{} = datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} min ago"
      diff < 86400 -> "#{div(diff, 3600)} hour ago"
      diff < 604_800 -> "#{div(diff, 86400)} day ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end

  defp relative_time(_), do: ""
end
