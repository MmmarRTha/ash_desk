defmodule AshDesk.Organizations.Organization do
  use Ash.Resource,
    otp_app: :ash_desk,
    domain: AshDesk.Organizations,
    data_layer: AshPostgres.DataLayer,
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
    end

    update :update do
      primary? true
      accept [:name]
      require_atomic? false
      change slugify(:name, into: :slug)
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
