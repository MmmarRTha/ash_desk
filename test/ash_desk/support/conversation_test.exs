defmodule AshDesk.Support.ConversationTest do
  use AshDesk.DataCase

  alias AshDesk.Support
  alias AshDesk.Organizations

  describe "conversations" do
    test "user can create a conversation" do
      {:ok, user} =
        Ash.create(
          AshDesk.Accounts.User,
          %{
            email: "agent@test.com",
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
          %{user_id: user.id, organization_id: org.id, role: :admin},
          actor: user,
          tenant: org.id
        )

      {:ok, conversation} =
        Support.create_conversation(
          %{organization_id: org.id},
          actor: user,
          tenant: org.id
        )

      assert conversation.organization_id == org.id
      assert conversation.status == :open
    end

    test "user can list conversations in their org" do
      {:ok, user} =
        Ash.create(
          AshDesk.Accounts.User,
          %{
            email: "agent@test.com",
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
          %{user_id: user.id, organization_id: org.id, role: :admin},
          actor: user,
          tenant: org.id
        )

      {:ok, conv1} =
        Support.create_conversation(
          %{organization_id: org.id},
          actor: user,
          tenant: org.id
        )

      {:ok, conv2} =
        Support.create_conversation(
          %{organization_id: org.id},
          actor: user,
          tenant: org.id
        )

      {:ok, conversations} = Support.list_conversations(actor: user, tenant: org.id)

      conversation_ids = Enum.map(conversations, & &1.id)
      assert conv1.id in conversation_ids
      assert conv2.id in conversation_ids
    end

    test "user cannot read conversations from another org" do
      {:ok, user1} =
        Ash.create(
          AshDesk.Accounts.User,
          %{
            email: "agent1@test.com",
            password: "password123",
            password_confirmation: "password123"
          },
          action: :register_with_password,
          authorize?: false
        )

      {:ok, org1} =
        Organizations.create_organization(
          %{name: "Org One"},
          actor: user1
        )

      {:ok, _membership} =
        Organizations.create_membership(
          %{user_id: user1.id, organization_id: org1.id, role: :admin},
          actor: user1,
          tenant: org1.id
        )

      {:ok, _conversation} =
        Support.create_conversation(
          %{organization_id: org1.id},
          actor: user1,
          tenant: org1.id
        )

      {:ok, user2} =
        Ash.create(
          AshDesk.Accounts.User,
          %{
            email: "agent2@test.com",
            password: "password123",
            password_confirmation: "password123"
          },
          action: :register_with_password,
          authorize?: false
        )

      {:ok, org2} =
        Organizations.create_organization(
          %{name: "Org Two"},
          actor: user2
        )

      {:ok, _membership} =
        Organizations.create_membership(
          %{user_id: user2.id, organization_id: org2.id, role: :admin},
          actor: user2,
          tenant: org2.id
        )

      {:ok, conversations} = Support.list_conversations(actor: user2, tenant: org2.id)

      assert conversations == []
    end

    test "user can assign a conversation" do
      {:ok, user} =
        Ash.create(
          AshDesk.Accounts.User,
          %{
            email: "agent@test.com",
            password: "password123",
            password_confirmation: "password123"
          },
          action: :register_with_password,
          authorize?: false
        )

      {:ok, agent} =
        Ash.create(
          AshDesk.Accounts.User,
          %{
            email: "agent2@test.com",
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
          %{user_id: user.id, organization_id: org.id, role: :admin},
          actor: user,
          tenant: org.id
        )

      {:ok, conversation} =
        Support.create_conversation(
          %{organization_id: org.id},
          actor: user,
          tenant: org.id
        )

      assert conversation.assigned_agent_id == nil

      {:ok, updated} =
        Support.update_conversation(
          conversation,
          %{assigned_agent_id: agent.id},
          actor: user,
          tenant: org.id
        )

      assert updated.assigned_agent_id == agent.id
    end

    test "get conversation by id" do
      {:ok, user} =
        Ash.create(
          AshDesk.Accounts.User,
          %{
            email: "agent@test.com",
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
          %{user_id: user.id, organization_id: org.id, role: :admin},
          actor: user,
          tenant: org.id
        )

      {:ok, conversation} =
        Support.create_conversation(
          %{organization_id: org.id},
          actor: user,
          tenant: org.id
        )

      {:ok, fetched} =
        Support.get_conversation_by_id(conversation.id, actor: user, tenant: org.id)

      assert fetched.id == conversation.id
      assert fetched.status == :open
    end
  end
end
