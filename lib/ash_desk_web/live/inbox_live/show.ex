defmodule AshDeskWeb.InboxLive.Show do
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
        membership =
          case AshDesk.Organizations.list_memberships(
                 actor: current_user,
                 tenant: org.id
               ) do
            {:ok, ms} -> Enum.find(ms, &(&1.user_id == current_user.id))
            _ -> nil
          end

        if membership && membership.role == :customer do
          {:ok, redirect(socket, to: ~p"/chat")}
        else
          {:ok, assign(socket, :org, org)}
        end

      _ ->
        {:ok,
         socket
         |> assign(:org, nil)
         |> assign(:organization_missing, true)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_user} admin={@is_admin}>
      <div class="bg-base-200/80 rounded-box border border-base-300 p-6 flex flex-col">
        <!-- Header with status controls -->
        <div class="flex items-center justify-between mb-4 shrink-0 flex-wrap gap-2">
          <div class="flex items-center gap-3">
            <.link
              navigate={~p"/inbox"}
              class="btn btn-ghost btn-sm btn-circle"
            >
              <.icon name="hero-arrow-left" class="size-5" />
            </.link>
            <div>
              <h1 class="text-lg font-semibold">{@org.name}</h1>
              <p class="text-xs opacity-50">Conversation</p>
            </div>
          </div>

          <div class="flex items-center gap-3">
            <div :if={@can_change_status} class="flex items-center gap-1">
              <button
                :for={s <- [:open, :pending, :resolved]}
                phx-click="change_status"
                phx-value-status={s}
                class={[
                  "btn btn-xs rounded-full",
                  @conversation.status == s && "btn-accent",
                  @conversation.status != s && "btn-ghost"
                ]}
              >
                {s}
              </button>
            </div>

            <.presence_indicators users={@online_users} />

            <div :if={@is_admin} class="flex items-center gap-2">
              <.icon name="hero-user-group" class="size-4 opacity-70" />
              <form id="assign-agent-form" phx-change="assign_agent">
                <select name="agent_id" class="select select-bordered select-sm text-accent">
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

        <!-- Messages area -->
        <div id="messages" phx-update="stream" class="flex-1 overflow-y-auto space-y-1 py-4">
          <.empty_state
            :if={@streams.messages == []}
            title="No messages yet"
            message="Send the first message!"
          />
          <div
            :for={{id, message} <- @streams.messages}
            id={id}
          >
            <.message_bubble
              message={message}
              current_user={@current_user}
              online_users={@online_users}
            />
          </div>
        </div>

        <!-- Typing indicator -->
        <.typing_indicator users={@typing_users} />

        <!-- Input area -->
        <div class="shrink-0 pb-2">
          <.message_input form={@message_form} input_id={@message_input_id} />
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(_params, _uri, %{assigns: %{organization_missing: true}} = socket) do
    {:noreply,
     socket
     |> put_flash(:error, "No organization found")
     |> push_navigate(to: ~p"/pending")}
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
              |> assign(:conversation, conversation)
              |> assign(:agents, [])
              |> assign(:is_admin, false)
              |> assign(:can_change_status, false)
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
             |> push_navigate(to: ~p"/inbox")}
        end
    end
  end

  @impl true
  def handle_event("change_status", %{"status" => status}, socket) do
    status = String.to_existing_atom(status)
    current_user = socket.assigns.current_user

    case AshDesk.Support.change_conversation_status(
           socket.assigns.conversation,
           status,
           actor: current_user,
           tenant: socket.assigns.org.id
         ) do
      {:ok, conversation} ->
        {:noreply, assign(socket, :conversation, conversation)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to change status: #{inspect(reason)}")}
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
        {:ok,
         {:ok,
          %{
            messages: messages,
            agents: agents,
            is_admin: is_admin,
            can_change_status: can_change_status
          }}},
        socket
      ) do
    {:noreply,
     socket
     |> stream(:messages, messages, reset: true)
     |> assign(:agents, agents)
     |> assign(:is_admin, is_admin)
     |> assign(:can_change_status, can_change_status)}
  end

  @impl true
  def handle_async(:fetch_messages, {:ok, {:error, reason}}, socket) do
    require Logger
    Logger.error("fetch_messages failed: #{inspect(reason)}")

    {:noreply, put_flash(socket, :error, "Failed to load conversation. Please try again.")}
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
      current_membership = Enum.find(memberships, &(&1.user_id == current_user.id))

      {:ok,
       %{
         messages: messages,
         agents: Enum.map(memberships, & &1.user),
         is_admin: current_membership && current_membership.role == :admin,
         can_change_status: current_membership && current_membership.role in [:admin, :agent]
       }}
    end
  end
end
