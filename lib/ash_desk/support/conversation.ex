defmodule AshDesk.Support.Conversation do
  use Ash.Resource,
    otp_app: :ash_desk,
    domain: AshDesk.Support,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "conversations"
    repo AshDesk.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:organization_id, :assigned_agent_id, :status, :subject],
      update: [:assigned_agent_id, :status]
    ]

    create :create_by_customer do
      accept [:subject, :organization_id]
      change set_attribute(:customer_id, actor(:id))
      change set_attribute(:status, :open)
    end

    read :list_assigned_to do
      description "List conversations assigned to a specific agent"
      argument :agent_id, :uuid, allow_nil?: false
      filter expr(assigned_agent_id == ^arg(:agent_id))
      prepare build(load: [:assigned_agent])
    end

    read :list_for_customer do
      description "List conversations for an specific customer"
      argument :customer_id, :uuid, allow_nil?: false
      filter expr(customer_id == ^arg(:customer_id))
      prepare build(sort: [created_at: :desc])
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(
                     exists(organization.memberships, user_id == ^actor(:id) and role == :admin)
                   )

      authorize_if expr(assigned_agent_id == ^actor(:id))
      authorize_if expr(customer_id == ^actor(:id))
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

  pub_sub do
    module AshDeskWeb.Endpoint
    prefix "conversation:meta"
    publish :update, [:id], load: [:assigned_agent]

    prefix "org:conversations"
    publish :create, [:organization_id]
    publish :update, [:organization_id]
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  attributes do
    uuid_primary_key :id

    attribute :subject, :string do
      allow_nil? true
      public? true
    end

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

    belongs_to :customer, AshDesk.Accounts.User do
      source_attribute :customer_id
      allow_nil? true
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
