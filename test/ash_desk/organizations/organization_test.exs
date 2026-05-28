defmodule AshDesk.Organizations.OrganizationTest do
  use AshDesk.DataCase
  alias AshDesk.Organizations

  describe "organizations" do
    test "user can create organization" do
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
          %{name: "Acme Inc"},
          actor: user
        )

      assert org.name == "Acme Inc"
      assert org.slug == "acme-inc"
    end

    test "user cannot read organization without membership" do
      {:ok, user1} =
        Ash.create(
          AshDesk.Accounts.User,
          %{
            email: "admin1@test.com",
            password: "password123",
            password_confirmation: "password123"
          },
          action: :register_with_password,
          authorize?: false
        )

      {:ok, user2} =
        Ash.create(
          AshDesk.Accounts.User,
          %{
            email: "admin2@test.com",
            password: "password123",
            password_confirmation: "password123"
          },
          action: :register_with_password,
          authorize?: false
        )

      {:ok, org} =
        Organizations.create_organization(
          %{name: "Acme"},
          actor: user1
        )

      {:ok, _membership} =
        Organizations.create_membership(
          %{
            user_id: user1.id,
            organization_id: org.id,
            role: :admin
          },
          actor: user1,
          tenant: org.id
        )

      {:ok, orgs} =
        Organizations.list_organizations(actor: user2)

      assert orgs == []
    end
  end
end
