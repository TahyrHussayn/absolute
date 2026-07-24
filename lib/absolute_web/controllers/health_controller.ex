defmodule AbsoluteWeb.HealthController do
  use AbsoluteWeb, :controller

  alias Ecto.Adapters.SQL

  def check(conn, _params) do
    db_status =
      case SQL.query(Absolute.Repo, "SELECT 1", []) do
        {:ok, _} -> "up"
        _ -> "down"
      end

    json(conn, %{
      status: "ok",
      node: to_string(Node.self()),
      database: db_status,
      timestamp: System.system_time(:second)
    })
  end
end
