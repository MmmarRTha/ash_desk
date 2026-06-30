defmodule AshDeskWeb.AdminLive.Index do
  use AshDeskWeb, :live_view

  on_mount {AshDeskWeb.LiveUserAuth, :live_user_required}
  on_mount {AshDeskWeb.LiveUserAuth, :current_user}

  import AshDeskWeb.Helpers

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    orgs = AshDesk.Organizations.list_organizations!(actor: current_user)

    admin_orgs_with_counts =
      orgs
      |> Enum.map(fn org ->
        memberships =
          AshDesk.Organizations.list_memberships!(
            actor: current_user,
            tenant: org.id
          )

        %{org: org, memberships: memberships}
      end)
      |> Enum.filter(fn %{memberships: ms} ->
        Enum.any?(ms, &(&1.user_id == current_user.id && &1.role == :admin))
      end)
      |> Enum.map(fn %{org: org, memberships: ms} ->
        %{org: org, member_count: length(ms)}
      end)

    {:ok,
     assign(socket,
       page_title: "Admin",
       admin_orgs: admin_orgs_with_counts,
       is_admin: length(admin_orgs_with_counts) > 0
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_user} admin={@is_admin}>
      <div class="bg-base-200/80 backdrop-blur-sm rounded-box border border-base-300 p-6">
        <div class="flex items-center justify-between mb-6">
          <div>
            <h1 class="text-2xl font-bold">Admin Dashboard</h1>
            <p class="text-sm text-base-content/60 mt-1">Manage organizations and their members</p>
          </div>
        </div>

        <div :if={@admin_orgs == []} class="text-center py-16">
          <.icon name="hero-shield-exclamation" class="size-16 opacity-30 mx-auto mb-4" />
          <h3 class="text-lg font-medium opacity-70">No organizations to manage</h3>
          <p class="text-sm opacity-50 mt-1">
            You don't have admin access to any organization yet.
            Contact your organization administrator to get access.
          </p>
        </div>

        <div :if={@admin_orgs != []}>
          <div class="overflow-x-auto">
            <table class="table">
              <thead>
                <tr>
                  <th>Organization</th>
                  <th>Slug</th>
                  <th>Members</th>
                  <th>Created</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={entry <- @admin_orgs}>
                  <td class="font-medium">{entry.org.name}</td>
                  <td class="text-sm opacity-60">{entry.org.slug}</td>
                  <td>{entry.member_count}</td>
                  <td class="text-sm opacity-60">{relative_time(entry.org.created_at)}</td>
                  <td>
                    <.link
                      navigate={~p"/admin/#{entry.org.slug}/members"}
                      class="btn btn-ghost btn-xs"
                    >
                      Manage Members
                    </.link>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
