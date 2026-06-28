defmodule AshDesk.Support do
  use Ash.Domain, otp_app: :ash_desk, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource AshDesk.Support.Conversation do
      define :create_conversation, action: :create
      define :get_conversation_by_id, action: :read, get_by: :id
      define :list_conversations, action: :read
      define :list_conversations_for_agent, action: :list_assigned_to
      define :list_conversations_by_status, action: :list_by_status, args: [:status]
      define :update_conversation, action: :update
      define :list_conversations_for_customer, action: :list_for_customer, args: [:customer_id]
      define :create_conversation_by_customer, action: :create_by_customer, args: [:subject]
      define :change_conversation_status, action: :change_status, args: [:status]
    end

    resource AshDesk.Support.Message do
      define :create_message, action: :create
      define :list_messages, action: :read
      define :list_messages_for_conversation, action: :list_messages_for_conversation
    end
  end

  def load_customer_portal(user) do
    case AshDesk.Organizations.list_organizations(actor: user) do
      {:ok, [org | _]} ->
        conversations =
          case AshDesk.Support.list_conversations_for_customer(user.id,
                 actor: user,
                 tenant: org.id
               ) do
            {:ok, convs} -> convs
            _ -> []
          end

        {:ok, %{org: org, conversations: conversations}}

      _ ->
        {:ok, %{org: nil, conversations: []}}
    end
  end
end
