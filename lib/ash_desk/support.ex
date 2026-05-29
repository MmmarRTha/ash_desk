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
      define :update_conversation, action: :update
    end

    resource AshDesk.Support.Message do
      define :create_message, action: :create
      define :list_messages, action: :read
      define :list_messages_for_conversation, action: :list_messages_for_conversation
    end
  end
end
