defmodule AshDesk.Support.Message do
  use Ash.Resource,
    otp_app: :ash_desk,
    domain: AshDesk.Support,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "messages"
    repo AshDesk.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:body, :conversation_id]
      change AshDesk.Support.Changes.SetSenderChange
    end

    read :list_messages_for_conversation do
      description "List messages for a specific conversation"
      argument :conversation_id, :uuid, allow_nil?: false
      filter expr(conversation_id == ^arg(:conversation_id))
      prepare build(load: [:sender])
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(exists(conversation.organization.memberships, user_id == ^actor(:id)))
    end

    policy action_type(:create) do
      authorize_if expr(exists(conversation.organization.memberships, user_id == ^actor(:id)))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :body, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :conversation, AshDesk.Support.Conversation do
      allow_nil? false
      public? true
    end

    belongs_to :sender, AshDesk.Accounts.User do
      allow_nil? false
      public? true
    end
  end
end
