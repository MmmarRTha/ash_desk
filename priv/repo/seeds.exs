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

for user <- [agent1, agent2] do
  {:ok, _membership} =
    Organizations.create_membership(%{user_id: user.id, organization_id: org.id, role: :agent},
      actor: user,
      tenant: org.id
    )
end

{:ok, conversation} =
  Support.create_conversation(
    %{organization_id: org.id, assigned_agent_id: agent1.id},
    actor: agent1,
    tenant: org.id
  )

messages = [
  %{body: "Hi, I need help with my order #1234.", sender_id: agent2.id},
  %{body: "Sure! Let me look that up. What seems to be the issue?", sender_id: agent1.id},
  %{body: "The package hasn't arrived yet and it's been two weeks.", sender_id: agent2.id}
]

for msg <- messages do
  {:ok, _message} =
    Support.create_message(
      %{body: msg.body, conversation_id: conversation.id, sender_id: msg.sender_id},
      actor: agent1
    )
end

IO.puts("Seeded #{length(users)} users, 1 org, 1 conversation, #{length(messages)} messages.")
IO.puts("Sign in as agent1@test.com with password #{password}")
