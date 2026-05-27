defmodule AshDesk.Organizations.Organization do
  use Ash.Resource,
    otp_app: :ash_desk,
    domain: AshDesk.Organizations,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "organizations"
    repo AshDesk.Repo
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

  identities do
    identity :unique_slug, [:slug]
  end
end
