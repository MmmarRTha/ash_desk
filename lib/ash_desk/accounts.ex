defmodule AshDesk.Accounts do
  use Ash.Domain, otp_app: :ash_desk, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource AshDesk.Accounts.Token

    resource AshDesk.Accounts.User do
      define :list_users, action: :read
      define :get_user_by_email, action: :get_by_email, args: [:email]
    end
  end
end
