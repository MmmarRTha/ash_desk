defmodule AshDesk.Organizations.Organization do
  use Ash.Resource,
    otp_app: :ash_desk,
    domain: AshDesk.Organizations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshSlug]

  postgres do
    table "organizations"
    repo AshDesk.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name]
      change slugify(:name, into: :slug)

      after_action(fn
        %{id: org_id} = org, %{context: %{actor: %{id: user_id}}} ->
          Ash.create(
            AshDesk.Organizations.Membership,
            %{
              user_id: user_id,
              organization_id: org_id,
              role: :admin
            }, actor: %{id: user_id}, authorize?: false, tenant: org_id)

          {:ok, org}

        org, _changeset ->
          {:ok, org}
      end)
    end

    update :update do
      primary? true
      accept [:name]
    end
  end

  policies do
    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type(:read) do
      authorize_if expr(exists(memberships, user_id == ^actor(:id)))
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(exists(memberships, user_id == ^actor(:id) and role == :admin))
    end
  end

  validations do
    validate match(:slug, ~r/^[a-z0-9-]+$/) do
      message "must only contain lowercase letters, numbers, and hyphens"
    end

    validate string_length(:name, min: 2, max: 50)
    validate string_length(:slug, min: 2, max: 50)
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :memberships, AshDesk.Organizations.Membership do
      public? true
    end
  end

  identities do
    identity :unique_slug, [:slug]
  end
end
