defmodule AbsoluteWeb.HealthControllerTest do
  use AbsoluteWeb.ConnCase

  test "GET /api/health returns ok status and node details", %{conn: conn} do
    conn = get(conn, ~p"/api/health")
    response = json_response(conn, 200)

    assert response["status"] == "ok"
    assert is_binary(response["node"])
    assert response["database"] in ["up", "down"]
  end
end
