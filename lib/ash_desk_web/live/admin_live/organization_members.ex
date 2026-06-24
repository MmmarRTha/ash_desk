defmodule AshDeskWeb.AdminLive.OrganizationMembers do
  use AshDeskWeb, :live_view

  on_mount {AshDeskWeb.LiveUserAuth, :live_user_required}
  on_mount {AshDeskWeb.LiveUserAuth, :current_user}

  import AshDeskWeb.Helpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Organization Members", email: "", role: "agent")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, load_org(socket, params)}
  end

  defp load_org(socket, %{"id" => org_id}) do
    current_user = socket.assigns.current_user

    org = AshDesk.Organizations.get_organization_by_id!(org_id, actor: current_user)

    memberships =
      AshDesk.Organizations.list_memberships!(
        actor: current_user,
        tenant: org.id,
        load: [:user]
      )

    is_admin =
      Enum.any?(memberships, &(&1.user_id == current_user.id && &1.role == :admin))

    socket =
      socket
      |> assign(:org, org)
      |> assign(:memberships, memberships)
      |> assign(:is_admin, is_admin)
      |> assign(:page_title, "#{org.name} — Members")

    if is_admin do
      socket
    else
      socket
      |> put_flash(:error, "You don't have admin access to this organization")
      |> push_navigate(to: ~p"/admin")
    end
  end

  defp load_org(socket, _params), do: socket

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_member", %{"email" => email, "role" => role}, socket) do
    org = socket.assigns.org
    current_user = socket.assigns.current_user

    case AshDesk.Accounts.get_user_by_email(email, actor: current_user) do
      {:ok, user} ->
        case AshDesk.Organizations.create_membership(
               %{user_id: user.id, role: String.to_existing_atom(role)},
               tenant: org.id,
               actor: current_user
             ) do
          {:ok, _membership} ->
            socket =
              socket
              |> put_flash(:info, "#{user.email} added as #{role}")
              |> assign(:email, "")

            {:noreply, reload_members(socket)}

          {:error, error} ->
            message = friendly_error(error, user.email)
            {:noreply, put_flash(socket, :error, message)}
        end

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "No user found with email: #{email}")}
    end
  end

  @impl true
  def handle_event("change_role", %{"membership_id" => id, "role" => role}, socket) do
    org = socket.assigns.org
    current_user = socket.assigns.current_user

    membership = Enum.find(socket.assigns.memberships, &(&1.id == id))

    if membership do
      case AshDesk.Organizations.update_membership(
             membership,
             %{role: String.to_existing_atom(role)},
             tenant: org.id,
             actor: current_user
           ) do
        {:ok, _membership} ->
          {:noreply, reload_members(socket) |> put_flash(:info, "Role updated")}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, friendly_error(error))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_member", %{"membership_id" => id}, socket) do
    org = socket.assigns.org
    current_user = socket.assigns.current_user

    membership = Enum.find(socket.assigns.memberships, &(&1.id == id))

    if membership do
      case AshDesk.Organizations.delete_membership(
             membership,
             tenant: org.id,
             actor: current_user
           ) do
        {:ok, _membership} ->
          {:noreply, reload_members(socket) |> put_flash(:info, "Member removed")}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, friendly_error(error))}
      end
    else
      {:noreply, socket}
    end
  end

  defp reload_members(socket) do
    org = socket.assigns.org
    current_user = socket.assigns.current_user

    memberships =
      AshDesk.Organizations.list_memberships!(
        actor: current_user,
        tenant: org.id,
        load: [:user]
      )

    assign(socket, :memberships, memberships)
  end

  defp friendly_error(%{errors: errors}, _email \\ nil) do
    Enum.map_join(errors, "; ", fn
      %{message: message} -> message
      error -> Exception.message(error)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_user} admin={@is_admin}>
      <div class="bg-base-200/80 backdrop-blur-sm rounded-box border border-base-300 p-6">
        <div class="flex items-center justify-between mb-6">
          <div class="flex items-center gap-3">
            <.link
              navigate={~p"/admin"}
              class="btn btn-ghost btn-sm btn-circle"
              aria-label="Back to admin"
            >
              <.icon name="hero-arrow-left" class="size-4" />
            </.link>
            <div>
              <h1 class="text-2xl font-bold">{@org.name}</h1>
              <p class="text-sm text-base-content/60 mt-1">
                Manage members and their roles
              </p>
            </div>
          </div>
        </div>

        <div class="mb-6">
          <.form for={%{}} id="add-member-form" phx-submit="add_member" class="flex items-end gap-3">
            <div class="flex-1">
              <.input
                type="email"
                name="email"
                value={@email}
                placeholder="user@example.com"
                label="Email"
                required
              />
            </div>
            <div class="w-36">
              <.input
                type="select"
                name="role"
                label="Role"
                value="agent"
                options={[Admin: "admin", Agent: "agent", Customer: "customer"]}
              />
            </div>
            <button class="btn btn-primary" type="submit">
              <.icon name="hero-plus" class="size-4" /> Add Member
            </button>
          </.form>
        </div>

        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>Email</th>
                <th>Role</th>
                <th>Joined</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={membership <- @memberships}>
                <td class="font-medium">{(membership.user && membership.user.email) || "—"}</td>
                <td>
                  <form phx-change="change_role" id={"role-form-#{membership.id}"}>
                    <input type="hidden" name="membership_id" value={membership.id} />
                    <select
                      name="role"
                      class="select select-bordered select-xs"
                      onchange="this.form.requestSubmit()"
                    >
                      <option
                        value="admin"
                        selected={membership.role == :admin}
                      >
                        Admin
                      </option>
                      <option
                        value="agent"
                        selected={membership.role == :agent}
                      >
                        Agent
                      </option>
                      <option
                        value="customer"
                        selected={membership.role == :customer}
                      >
                        Customer
                      </option>
                    </select>
                  </form>
                </td>
                <td class="text-sm opacity-60">{relative_time(membership.created_at)}</td>
                <td>
                  <button
                    phx-click="remove_member"
                    phx-value-membership_id={membership.id}
                    phx-disable-with="Removing..."
                    class="btn btn-ghost btn-xs text-error"
                    data-confirm="Remove this member from the organization?"
                  >
                    Remove
                  </button>
                </td>
              </tr>
            </tbody>
          </table>

          <div :if={@memberships == []} class="text-center py-12">
            <.icon name="hero-user-group" class="size-12 opacity-30 mx-auto mb-3" />
            <p class="text-sm opacity-60">No members yet. Add one above.</p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
