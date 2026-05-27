defmodule AshDesk.Organizations do
  use Ash.Domain,
    otp_app: :ash_desk

  resources do
    resource AshDesk.Organizations.Organization
  end
end
