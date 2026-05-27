defmodule AshDesk.Organizations do
  use Ash.Domain,
    otp_app: :ash_desk

  resources do
    resource AshDesk.Organizations.Organization do
      define :create_organization, action: :create
      define :list_organizations, action: :read
      define :get_organization_by_slug, action: :read, get_by: :slug
      define :update_organization, action: :update
      define :delete_organization, action: :destroy
    end

    resource AshDesk.Organizations.Membership
  end
end
