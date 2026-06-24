{:ok, hashed_password} = AshAuthentication.BcryptProvider.hash("password123")

admin =
  Ash.Seed.seed!(AshDesk.Accounts.User, %{
    email: "admin@ashdesk.com",
    hashed_password: hashed_password,
    role: :admin
  })

Ash.Seed.seed!(AshDesk.Accounts.User, %{
  email: "agent1@ashdesk.com",
  hashed_password: hashed_password,
  role: :agent
})

customer =
  Ash.Seed.seed!(AshDesk.Accounts.User, %{
    email: "customer@ashdesk.com",
    hashed_password: hashed_password,
    role: :customer
  })

{:ok, org} = AshDesk.Organizations.create_organization(%{name: "KATS Inc"}, actor: admin)

# {:ok, _membership} =
#   AshDesk.Organizations.create_membership(
#     %{user_id: admin.id, organization_id: org.id, role: :admin},
#     actor: admin,
#     tenant: org.id
#   )

# {:ok, _membership} =
#   AshDesk.Organizations.create_membership(
#     %{user_id: customer.id, organization_id: org.id, role: :customer},
#     actor: customer,
#     tenant: org.id
#   )
