defmodule AshDesk.Organizations.MembershipTest do
  use AshDesk.DataCase
  alias AshDesk.Organizations

  describe "memberships" do
    test "user can belong to organization" do
      {:ok, user} =
        Ash.create(
          AshDesk.Accounts.User,
          %{
            email: "admin@test.com",
            password: "password123",
            password_confirmation: "password123"
          },
          action: :register_with_password,
          authorize?: false
        )

      {:ok, org} =
        Organizations.create_organization(
          %{name: "Acme"},
          actor: user
        )

      {:ok, membership} =
        Organizations.create_membership(
          %{
            user_id: user.id,
            organization_id: org.id,
            role: :admin
          },
          actor: user,
          tenant: org.id
        )

      assert membership.user_id == user.id
      assert membership.organization_id == org.id
      assert membership.role == :admin
    end

    test "duplicate memberships are rejected" do
      {:ok, user} =
        Ash.create(
          AshDesk.Accounts.User,
          %{
            email: "admin@test.com",
            password: "password123",
            password_confirmation: "password123"
          },
          action: :register_with_password,
          authorize?: false
        )

      {:ok, org} =
        Organizations.create_organization(
          %{name: "Acme"},
          actor: user
        )

      {:ok, _membership} =
        Organizations.create_membership(
          %{
            user_id: user.id,
            organization_id: org.id
          },
          actor: user,
          tenant: org.id,
          authorize?: false
        )

      result =
        Organizations.create_membership(
          %{
            user_id: user.id,
            organization_id: org.id
          },
          actor: user,
          tenant: org.id,
          authorize?: false
        )

      assert {:error, _} = result
    end
  end
end
