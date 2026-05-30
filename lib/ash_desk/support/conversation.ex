defmodule AshDesk.Support.Conversation do
  use Ash.Resource,
    otp_app: :ash_desk,
    domain: AshDesk.Support,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "conversations"
    repo AshDesk.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:organization_id, :assigned_agent_id, :status],
      update: [:assigned_agent_id, :status]
    ]
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(exists(organization.memberships, user_id == ^actor(:id)))
    end

    policy action_type(:create) do
      authorize_if expr(exists(organization.memberships, user_id == ^actor(:id)))
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(
                     exists(organization.memberships, user_id == ^actor(:id) and role == :admin)
                   )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  attributes do
    uuid_primary_key :id

    attribute :status, :atom do
      constraints one_of: [:open, :pending, :resolved]
      default :open
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization, AshDesk.Organizations.Organization do
      allow_nil? false
      public? true
    end

    belongs_to :assigned_agent, AshDesk.Accounts.User do
      source_attribute :assigned_agent_id
      allow_nil? true
      public? true
    end

    has_many :messages, AshDesk.Support.Message do
      public? true
    end
  end
end
