defmodule AshDeskWeb.InboxLive.Index do
  use AshDeskWeb, :live_view

  on_mount {AshDeskWeb.LiveUserAuth, :live_user_required}
  on_mount {AshDeskWeb.LiveUserAuth, :current_user}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    socket =
      case AshDesk.Organizations.list_organizations(actor: current_user) do
        {:ok, [org | _]} ->
          case AshDesk.Support.list_conversations(actor: current_user, tenant: org.id) do
            {:ok, conversations} ->
              {:ok, conversations} =
                Ash.load(conversations, [:assigned_agent],
                  actor: current_user,
                  authorize?: false
                )

              assign(socket, org: org, conversations: conversations)

            {:error, _reason} ->
              assign(socket, org: org, conversations: [])
          end

        _ ->
          assign(socket, org: nil, conversations: [])
      end

    {:ok, socket}
  end
end
