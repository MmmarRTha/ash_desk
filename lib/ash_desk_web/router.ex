defmodule AshDeskWeb.Router do
  use AshDeskWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AshDeskWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  scope "/", AshDeskWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated_routes do
      live "/inbox", InboxLive.Index, :index
      live "/inbox/:id", InboxLive.Show, :show
      live "/chat", ChatLive.Index, :index
      live "/chat/:id", ChatLive.Show, :show
      live "/admin", AdminLive.Index, :index
      live "/admin/organizations/:id/members", AdminLive.OrganizationMembers, :show
    end

    get "/", PageController, :home
    auth_routes AuthController, AshDesk.Accounts.User, path: "/auth"
    sign_out_route AuthController

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{AshDeskWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    AshDeskWeb.AuthOverrides,
                    Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  AshDeskWeb.AuthOverrides,
                  Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                ]

    # Remove this if you do not use the confirmation strategy
    confirm_route AshDesk.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [AshDeskWeb.AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(AshDesk.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [AshDeskWeb.AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]
    )
  end

  # Other scopes may use custom stacks.
  # scope "/api", AshDeskWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:ash_desk, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AshDeskWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  if Application.compile_env(:ash_desk, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end
end
