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

{:ok, org} =
  AshDesk.Organizations.create_organization(%{name: "MICHI Corp"}, actor: michi_admin)

{:ok, _membership} =
  AshDesk.Organizations.create_membership(
    %{user_id: michi_admin.id, organization_id: org.id, role: :admin},
    actor: michi_admin,
    tenant: org.id
  )
