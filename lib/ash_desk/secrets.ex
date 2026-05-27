defmodule AshDesk.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        AshDesk.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:ash_desk, :token_signing_secret)
  end
end
