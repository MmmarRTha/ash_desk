defmodule AshDesk.Support.Changes.SetSenderChange do
  use Ash.Resource.Change

  def change(changeset, _opts, context) do
    case context do
      %{actor: %{id: sender_id}} when not is_nil(sender_id) ->
        Ash.Changeset.force_change_new_attribute(changeset, :sender_id, sender_id)

      _ ->
        Ash.Changeset.add_error(changeset,
          field: :sender_id,
          message: "is required (must be authenticated)"
        )
    end
  end
end
