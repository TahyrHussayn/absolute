defmodule AbsoluteWeb.MetricsControllerTest do
  use AbsoluteWeb.ConnCase

  test "GET /metrics returns Prometheus text format metrics", %{conn: conn} do
    conn = get(conn, ~p"/metrics")
    response = response(conn, 200)

    assert response =~ "phoenix_endpoint_start_system_time" or response =~ "vm_memory_total"
  end
end
