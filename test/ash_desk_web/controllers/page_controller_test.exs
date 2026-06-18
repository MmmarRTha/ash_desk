defmodule AshDeskWeb.PageControllerTest do
  use AshDeskWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Support Inbox"
  end
end
