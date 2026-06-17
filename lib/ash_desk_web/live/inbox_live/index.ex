defmodule AshDeskWeb.InboxLive.Index do
  use AshDeskWeb, :live_view

  on_mount {AshDeskWeb.LiveUserAuth, :live_user_required}
  on_mount {AshDeskWeb.LiveUserAuth, :current_user}

  import AshDeskWeb.Helpers

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, :page_title, "Inbox")

    socket =
      if connected?(socket) do
        current_user = socket.assigns.current_user

        socket
        |> assign(:org, nil)
        |> assign(:status_filter, nil)
        |> stream(:conversations, [])
        |> start_async(:fetch_inbox, fn -> fetch_inbox_data(current_user, nil) end)
      else
        socket
        |> assign(:org, nil)
        |> assign(:status_filter, nil)
        |> stream(:conversations, [])
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_user}>
      <div class="flex justify-between items-center mb-4">
        <h1 class="text-2xl font-bold">
          {if @org, do: "#{@org.name} — Inbox", else: "Loading..."}
        </h1>
      </div>

      <div class="flex gap-1.5 mb-4">
        <button
          :for={
            {value, label} <- [
              {nil, "All"},
              {:open, "Open"},
              {:pending, "Pending"},
              {:resolved, "Resolved"}
            ]
          }
          phx-click="filter_status"
          phx-value-status={if value == nil, do: "", else: Atom.to_string(value)}
          class={[
            "btn btn-sm rounded-full",
            @status_filter == value && "btn-primary",
            @status_filter != value && "btn-ghost"
          ]}
        >
          {label}
        </button>
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
  def handle_event("filter_status", %{"status" => status}, socket) do
    status_filter = if status == "", do: nil, else: String.to_existing_atom(status)
    current_user = socket.assigns.current_user

    socket =
      socket
      |> assign(:status_filter, status_filter)
      |> cancel_async(:fetch_inbox)
      |> start_async(:fetch_inbox, fn -> fetch_inbox_data(current_user, status_filter) end)

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
          event: "update",
          payload: %Ash.Notifier.Notification{data: conversation}
        },
        socket
      ) do
    conversation =
      case Ash.load(conversation, [:assigned_agent], actor: socket.assigns.current_user) do
        {:ok, loaded} -> loaded
        _ -> conversation
      end

    {:noreply, stream_insert(socket, :conversations, conversation)}
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

  defp fetch_inbox_data(current_user, status_filter) do
    case AshDesk.Organizations.list_organizations(actor: current_user) do
      {:ok, [org | _]} ->
        opts = [actor: current_user, tenant: org.id]

        conversations =
          if status_filter do
            case AshDesk.Support.list_conversations_by_status(status_filter, opts) do
              {:ok, convs} -> convs
              {:error, _} -> []
            end
          else
            case AshDesk.Support.list_conversations(opts ++ [load: [:assigned_agent]]) do
              {:ok, convs} -> convs
              {:error, _} -> []
            end
          end

        %{org: org, conversations: conversations}

      _ ->
        %{org: nil, conversations: []}
    end
  end
end
