defmodule AshDeskWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  # configure your UI overrides here

  # First argument to `override` is the component name you are overriding.
  # The body contains any number of configurations you wish to override
  # Below are some examples

  # For a complete reference, see https://hexdocs.pm/ash_authentication_phoenix/ui-overrides.html

  # override AshAuthentication.Phoenix.Components.Banner do
  #   set :image_url, "https://media.giphy.com/media/g7GKcSzwQfugw/giphy.gif"
  #   set :text_class, "bg-red-500"
  # end

  # override AshAuthentication.Phoenix.Components.SignIn do
  #  set :show_banner, false
  # end
  #
  override AshAuthentication.Phoenix.Components.Banner do
    set :image_url, nil
    set :dark_image_url, nil

    set :text_class,
        "text-7xl font-bold bg-gradient-to-b from-primary to-secondary bg-clip-text"

    set :text, "AshDesk"
  end
end
