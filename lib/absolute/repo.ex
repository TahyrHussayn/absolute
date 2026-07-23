defmodule Absolute.Repo do
  use Ecto.Repo,
    otp_app: :absolute,
    adapter: Ecto.Adapters.Postgres
end
