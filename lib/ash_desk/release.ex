defmodule AshDesk.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :ash_desk

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed do
    {:ok, _} = Application.ensure_all_started(@app)

    import Ash.Query

    case Ash.read(AshDesk.Accounts.User) do
      {:ok, []} ->
        IO.puts("Running seeds...")
        do_seed()
        IO.puts("Seeds completed successfully")

      {:ok, _users} ->
        IO.puts("Seeds already present, skipping")
    end
  end

  defp do_seed do
    {:ok, hashed_password} = AshAuthentication.BcryptProvider.hash("password123")

    admin =
      Ash.Seed.seed!(AshDesk.Accounts.User, %{
        email: "admin@kats-inc.com",
        hashed_password: hashed_password
      })

    Ash.Seed.seed!(AshDesk.Accounts.User, %{
      email: "agent1@kats-inc.com",
      hashed_password: hashed_password
    })

    Ash.Seed.seed!(AshDesk.Accounts.User, %{
      email: "customer@kats-inc.com",
      hashed_password: hashed_password
    })

    {:ok, org} = AshDesk.Organizations.create_organization(%{name: "KATS Inc"}, actor: admin)

    {:ok, _membership} =
      AshDesk.Organizations.create_membership(
        %{user_id: admin.id, organization_id: org.id, role: :admin},
        actor: admin,
        tenant: org.id
      )

    michi_admin =
      Ash.Seed.seed!(AshDesk.Accounts.User, %{
        email: "admin@michi-corp.com",
        hashed_password: hashed_password
      })

    Ash.Seed.seed!(AshDesk.Accounts.User, %{
      email: "agent1@michi-corp.com",
      hashed_password: hashed_password
    })

    Ash.Seed.seed!(AshDesk.Accounts.User, %{
      email: "customer@michi-corp.com",
      hashed_password: hashed_password
    })

    {:ok, michi_org} =
      AshDesk.Organizations.create_organization(%{name: "MICHI Corp"}, actor: michi_admin)

    {:ok, _membership} =
      AshDesk.Organizations.create_membership(
        %{user_id: michi_admin.id, organization_id: michi_org.id, role: :admin},
        actor: michi_admin,
        tenant: michi_org.id
      )
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
