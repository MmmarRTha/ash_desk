defmodule AshDeskWeb.PendingLive.Index do
  use AshDeskWeb, :live_view

  on_mount {AshDeskWeb.LiveUserAuth, :live_user_required}
  on_mount {AshDeskWeb.LiveUserAuth, :current_user}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    socket =
      case Ash.load(current_user, :org_role) do
        {:ok, user} ->
          case user.org_role do
            :admin -> redirect(socket, to: ~p"/inbox")
            :agent -> redirect(socket, to: ~p"/inbox")
            :customer -> redirect(socket, to: ~p"/chat")
            :none -> assign(socket, page_title: "Access Pending")
          end

        _ ->
          assign(socket, page_title: "Access Pending")
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_user}>
      <div class="bg-base-200/80 backdrop-blur-sm rounded-box border border-base-300 p-12 text-center">
        <div class="max-w-md mx-auto">
          <div class="avatar placeholder mb-6">
            <div class="bg-primary/20 text-primary rounded-full w-20">
              <.icon name="hero-user-group" class="size-10" />
            </div>
          </div>

          <h1 class="text-2xl font-bold mb-3">Waiting for Access</h1>
          <p class="text-base-content/60 mb-6">
            Your account has been created, but you haven't been added to an organization yet.
            Contact your organization administrator to get access.
          </p>

          <div class="bg-base-300/50 rounded-box p-4 mb-6">
            <p class="text-sm text-base-content/50 mb-1">Your email</p>
            <p class="font-mono font-medium">{@current_user.email}</p>
          </div>

          <p class="text-sm text-base-content/50 mb-6">
            Share this email with your admin so they can add you to their organization.
          </p>

          <.link href="/sign-out" method="delete" class="btn btn-ghost btn-sm">
            Sign Out
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
