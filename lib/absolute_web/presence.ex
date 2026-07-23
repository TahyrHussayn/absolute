defmodule AbsoluteWeb.Presence do
  @moduledoc """
  Provides real-time presence tracking across BEAM cluster nodes using CRDTs.
  """
  use Phoenix.Presence,
    otp_app: :absolute,
    pubsub_server: Absolute.PubSub
end
