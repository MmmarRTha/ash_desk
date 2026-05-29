defmodule AshDeskWeb.InboxLive.Index do
  use AshDeskWeb, :live_view

  on_mount {AshDeskWeb.LiveUserAuth, :live_user_required}
  on_mount {AshDeskWeb.LiveUserAuth, :current_user}

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, :page_title, "Inbox")

    socket =
      if connected?(socket) do
        current_user = socket.assigns.current_user

        socket
        |> assign(:org, nil)
        |> stream(:conversations, [])
        |> start_async(:fetch_inbox, fn -> fetch_inbox_data(current_user) end)
      else
        socket
        |> assign(:org, nil)
        |> stream(:conversations, [])
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_user}>
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold">
          {if @org, do: "#{@org.name} — Inbox", else: "Loading..."}
        </h1>
      </div>

      <div id="conversations" phx-update="stream">
        <div id="conversations-empty" class="hidden only:block text-center py-12 opacity-50">
          No conversations yet.
        </div>
        <div
          :for={{id, conversation} <- @streams.conversations}
          id={id}
          class="card bg-base-200 p-4 mb-3"
        >
          <.link navigate={~p"/inbox/#{conversation.id}"} class="block">
            <div class="flex justify-between items-center">
              <span class="font-medium">
                {(conversation.assigned_agent && conversation.assigned_agent.email) || "Unassigned"}
              </span>
              <span class="badge">{conversation.status}</span>
            </div>
            <div class="text-sm opacity-70 mt-1">
              Created: {conversation.created_at}
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
  def handle_async(:fetch_inbox, {:ok, %{org: org, conversations: conversations}}, socket) do
    {:noreply,
     socket
     |> assign(:org, org)
     |> stream(:conversations, conversations, reset: true)}
  end

  def handle_async(:fetch_inbox, {:exit, _reason}, socket) do
    {:noreply, socket}
  end

  defp fetch_inbox_data(current_user) do
    case AshDesk.Organizations.list_organizations(actor: current_user) do
      {:ok, [org | _]} ->
        case AshDesk.Support.list_conversations(actor: current_user, tenant: org.id) do
          {:ok, conversations} ->
            {:ok, conversations} =
              Ash.load(conversations, [:assigned_agent],
                actor: current_user,
                authorize?: false
              )

            %{org: org, conversations: conversations}

          {:error, _error} ->
            %{org: org, conversations: []}
        end

      _ ->
        %{org: nil, conversations: []}
    end
  end
end
