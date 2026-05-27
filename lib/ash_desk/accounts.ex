defmodule AshDesk.Accounts do
  use Ash.Domain, otp_app: :ash_desk, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource AshDesk.Accounts.Token
    resource AshDesk.Accounts.User
  end
end
