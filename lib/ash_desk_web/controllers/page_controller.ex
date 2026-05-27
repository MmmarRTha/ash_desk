defmodule AshDeskWeb.PageController do
  use AshDeskWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
