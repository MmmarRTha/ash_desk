defmodule AshDeskWeb.InboxLiveTest do
  use AshDeskWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AshDesk.Organizations
  alias AshDesk.Support

  defp create_user_and_org(_context) do
    {:ok, user} =
      Ash.create(
        AshDesk.Accounts.User,
        %{email: "agent@test.com", password: "password123", password_confirmation: "password123"},
        action: :register_with_password,
        authorize?: false
      )

    {:ok, org} = Organizations.create_organization(%{name: "Acme"}, actor: user)

    {:ok, _membership} =
      Organizations.create_membership(
        %{user_id: user.id, organization_id: org.id, role: :admin},
        actor: user,
        tenant: org.id
      )

    {:ok, conversation} =
      Support.create_conversation(%{organization_id: org.id}, actor: user, tenant: org.id)

    %{user: user, org: org, conversation: conversation}
  end

  defp sign_in(conn, user) do
    conn
    |> init_test_session(%{})
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
  end

  describe "index" do
    setup [:create_user_and_org]

    test "redirects to sign-in when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/inbox")
    end

    test "lists conversations in the inbox", %{conn: conn, user: user, conversation: conversation} do
      conn = sign_in(conn, user)
      {:ok, view, _html} = live(conn, ~p"/inbox")

      html = render_async(view)

      assert html =~ "Acme — Inbox"
      assert has_element?(view, ~s/a[href="#{~p"/inbox/#{conversation.id}"}"]/)
    end
  end

  describe "show" do
    setup [:create_user_and_org]

    test "shows conversation messages", %{conn: conn, user: user, conversation: conversation} do
      {:ok, _message} =
        Support.create_message(
          %{body: "Hello! Need help.", conversation_id: conversation.id},
          actor: user
        )

      conn = sign_in(conn, user)
      {:ok, view, _html} = live(conn, ~p"/inbox/#{conversation.id}")

      html = render_async(view)

      assert has_element?(view, ~s/a[href="#{~p"/inbox"}"]/)
      assert html =~ "Hello! Need help."
      assert html =~ "Me"
      assert has_element?(view, "#send-message-form")
    end

    test "user can send a message", %{conn: conn, user: user, conversation: conversation} do
      conn = sign_in(conn, user)
      {:ok, view, _html} = live(conn, ~p"/inbox/#{conversation.id}")

      render_async(view)

      view
      |> element("#send-message-form")
      |> render_submit(%{body: "New message body"})

      assert has_element?(view, "p", "New message body")
    end

    test "redirects to inbox for non-existent conversation", %{conn: conn, user: user} do
      conn = sign_in(conn, user)

      assert {:error, {:live_redirect, %{to: "/inbox"}}} =
               live(conn, ~p"/inbox/non-existent-id")
    end
  end
end
