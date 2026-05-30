defmodule AshDesk.Support.MessageTest do
  use AshDesk.DataCase

  alias AshDesk.Support
  alias AshDesk.Organizations

  describe "messages" do
    test "user can send message in conversation they belong to" do
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

      {:ok, message} =
        Support.create_message(
          %{
            body: "Hello! Need help with my order.",
            conversation_id: conversation.id
          },
          actor: user
        )

      assert message.body == "Hello! Need help with my order."
      assert message.conversation_id == conversation.id
      assert message.sender_id == user.id
    end

    test "user cannot read messages from conversations outside their org" do
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

      {:ok, conversation} =
        Support.create_conversation(
          %{organization_id: org1.id},
          actor: user1,
          tenant: org1.id
        )

      {:ok, _message} =
        Support.create_message(
          %{
            body: "Secret message",
            conversation_id: conversation.id
          },
          actor: user1
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

      {:ok, messages} = Support.list_messages(actor: user2)

      assert messages == []
    end

    test "multiple messages are returned in a conversation" do
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

      {:ok, msg1} =
        Support.create_message(
          %{
            body: "First message",
            conversation_id: conversation.id
          },
          actor: user
        )

      {:ok, msg2} =
        Support.create_message(
          %{
            body: "Second message",
            conversation_id: conversation.id
          },
          actor: user
        )

      {:ok, messages} = Support.list_messages(actor: user)

      message_ids = Enum.map(messages, & &1.id)
      assert msg1.id in message_ids
      assert msg2.id in message_ids
      assert length(messages) == 2
    end
  end
end
