defmodule AshDesk.Organizations do
  use Ash.Domain, otp_app: :ash_desk, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource AshDesk.Organizations.Organization do
      define :create_organization, action: :create
      define :list_organizations, action: :read
      define :get_organization_by_id, action: :read, get_by: :id
      define :get_organization_by_slug, action: :read, get_by: :slug
      define :update_organization, action: :update
      define :delete_organization, action: :destroy
    end

    resource AshDesk.Organizations.Membership do
      define :create_membership, action: :create
      define :list_memberships, action: :read
      define :get_membership_by_id, action: :read, get_by: :id
      define :update_membership, action: :update
      define :delete_membership, action: :destroy
    end
  end
end
