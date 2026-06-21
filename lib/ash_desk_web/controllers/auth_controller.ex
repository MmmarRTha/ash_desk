defmodule AshDeskWeb.AuthController do
  use AshDeskWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, activity, user, _token) do
    return_to = get_session(conn, :return_to) || default_path_for(user)

    message =
      case activity do
        {:confirm_new_user, :confirm} -> "Your email address has now been confirmed"
        {:password, :reset} -> "Your password has successfully been reset"
        _ -> "You are now signed in"
      end

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    # If your resource has a different name, update the assign name here (i.e :current_admin)
    |> assign(:current_user, user)
    |> put_flash(:info, message)
    |> redirect(to: return_to)
  end

  def failure(conn, activity, reason) do
    message =
      case {activity, reason} do
        {_,
         %AshAuthentication.Errors.AuthenticationFailed{
           caused_by: %Ash.Error.Forbidden{
             errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
           }
         }} ->
          """
          You have already signed in another way, but have not confirmed your account.
          You can confirm your account using the link we sent to you, or by resetting your password.
          """

        _ ->
          "Incorrect email or password"
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session(:ash_desk)
    |> put_flash(:info, "You are now signed out")
    |> redirect(to: return_to)
  end

  defp default_path_for(user) do
    case AshDesk.Organizations.list_organizations(actor: user, authorize?: false) do
      {:ok, orgs} ->
        orgs
        |> Enum.find_value(fn org ->
          case AshDesk.Organizations.list_memberships(
                 actor: user,
                 tenant: org.id,
                 authorize?: false,
                 query: [filter: [user_id: user.id]]
               ) do
            {:ok, [%{role: role} | _]} when role in [:admin, :agent] -> ~p"/inbox"
            _ -> nil
          end
        end) || ~p"/chat"

      _ ->
        ~p"/chat"
    end
  end
end
