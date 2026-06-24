defmodule AshDeskWeb.InboxLive.Index do
  use AshDeskWeb, :live_view

  on_mount {AshDeskWeb.LiveUserAuth, :live_user_required}
  on_mount {AshDeskWeb.LiveUserAuth, :current_user}

  import AshDeskWeb.Helpers
  import Cinder.Refresh

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
          socket =
            if connected?(socket) do
              Phoenix.PubSub.subscribe(AshDesk.PubSub, "org:conversations:#{org.id}")
              socket
            else
              socket
            end

          is_admin = membership && membership.role == :admin
          {:ok, assign(socket, org: org, page_title: "Inbox", is_admin: is_admin)}
        end

      _ ->
        {:ok, assign(socket, org: nil, page_title: "Inbox")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_user} admin={@is_admin}>
      <div class="bg-base-200/80 backdrop-blur-sm rounded-box border border-base-300 p-6">
        <h1 class="text-2xl font-bold mb-4">
          {if @org, do: "#{@org.name} — Inbox", else: "Loading..."}
        </h1>

        <div :if={@org}>
          <Cinder.collection
            id="inbox-collection"
            resource={AshDesk.Support.Conversation}
            actor={@current_user}
            tenant={@org.id}
            page_size={[default: 25, options: [10, 25, 50, 100]]}
            theme="daisy_ui"
            query_opts={[load: [:assigned_agent]]}
            click={fn conv -> JS.navigate(~p"/inbox/#{conv.id}") end}
          >
            <:col :let={conv} field="assigned_agent.email" label="Agent" sort>
              {(conv.assigned_agent && conv.assigned_agent.email) || "Unassigned"}
            </:col>
            <:col :let={conv} field="subject" label="Subject">
              {conv.subject || "—"}
            </:col>
            <:col :let={conv} field="status" sort>
              {conv.status}
            </:col>
            <:col :let={conv} field="created_at" label="Date" sort>
              {relative_time(conv.created_at)}
            </:col>

            <:empty :let={context}>
              <div class="text-center py-16">
                <.icon name="hero-chat-bubble-left-right" class="size-16 opacity-30 mx-auto mb-4" />
                <h3 class="text-lg font-medium opacity-70">
                  {if context.filtered?,
                    do: "No results match your filters.",
                    else: "No conversations yet."}
                </h3>
                <p class="text-sm opacity-50 mt-1">
                  Conversations will appear here when customers reach out.
                </p>
              </div>
            </:empty>
          </Cinder.collection>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "org:conversations:" <> _
        },
        socket
      ) do
    {:noreply, refresh_table(socket, "inbox-collection")}
  end
end
