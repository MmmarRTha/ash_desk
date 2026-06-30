defmodule AshDeskWeb.PageController do
  use AshDeskWeb, :controller

  def home(conn, _params) do
    org_slug =
      case conn.assigns[:current_user] do
        nil ->
          nil

        user ->
          case AshDesk.Organizations.list_organizations(actor: user) do
            {:ok, [org | _]} -> org.slug
            _ -> nil
          end
      end

    render(conn, :home, org_slug: org_slug)
  end
end
