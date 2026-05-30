defmodule AshDesk.Organizations.Membership do
  use Ash.Resource,
    otp_app: :ash_desk,
    domain: AshDesk.Organizations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "memberships"
    repo AshDesk.Repo
  end

  actions do
    defaults [:read, :destroy, create: [:role, :user_id, :organization_id], update: [:role]]
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(exists(organization.memberships, user_id == ^actor(:id)))
    end

    # MVP: any authenticated user can be added to an org.
    # Tighten to admin-only for production.
    policy action_type(:create) do
      authorize_if actor_present()
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

    attribute :role, :atom do
      constraints one_of: [:admin, :agent]
      default :agent
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization, AshDesk.Organizations.Organization do
      public? true
    end

    belongs_to :user, AshDesk.Accounts.User do
      public? true
    end
  end

  identities do
    identity :unique_membership, [:user_id, :organization_id]
  end
end
