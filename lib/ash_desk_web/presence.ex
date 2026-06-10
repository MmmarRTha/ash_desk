defmodule AshDeskWeb.Presence do
  use Phoenix.Presence,
    otp_app: :ash_desk,
    pubsub_server: AshDesk.PubSub
end
