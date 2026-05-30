alias AshDesk.Accounts.User
alias AshDesk.Organizations
alias AshDesk.Support

password = "password123"

users =
  Enum.map(["agent1@test.com", "agent2@test.com"], fn email ->
    {:ok, user} =
      Ash.create(User, %{email: email, password: password, password_confirmation: password},
        action: :register_with_password,
        authorize?: false
      )

    user
  end)

[agent1, agent2] = users

{:ok, org} = Organizations.create_organization(%{name: "Acme Inc"}, actor: agent1)

{:ok, _membership} =
  Organizations.create_membership(
    %{user_id: agent1.id, organization_id: org.id, role: :admin},
    actor: agent1,
    tenant: org.id
  )

{:ok, _membership} =
  Organizations.create_membership(
    %{user_id: agent2.id, organization_id: org.id, role: :agent},
    actor: agent1,
    tenant: org.id
  )

{:ok, conversation} =
  Support.create_conversation(
    %{organization_id: org.id, assigned_agent_id: agent1.id},
    actor: agent1,
    tenant: org.id
  )

{:ok, _unassigned_conv} =
  Support.create_conversation(
    %{organization_id: org.id, assigned_agent_id: nil},
    actor: agent1,
    tenant: org.id
  )

messages = [
  %{body: "Hi, I need help with my order #1234.", actor: agent2},
  %{body: "Sure! Let me look that up. What seems to be the issue?", actor: agent1},
  %{body: "The package hasn't arrived yet and it's been two weeks.", actor: agent2}
]

for msg <- messages do
  {:ok, _message} =
    Support.create_message(
      %{body: msg.body, conversation_id: conversation.id},
      actor: msg.actor,
      tenant: org.id
    )
end

IO.puts("Seeded #{length(users)} users, 1 org, 1 conversation, #{length(messages)} messages.")
IO.puts("Sign in as agent1@test.com with password #{password}")
