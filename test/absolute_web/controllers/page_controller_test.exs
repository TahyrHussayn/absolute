defmodule AbsoluteWeb.PageControllerTest do
  use AbsoluteWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Experience the Pure Magic of the"
  end

  test "GET /aws-guide", %{conn: conn} do
    conn = get(conn, ~p"/aws-guide")
    assert html_response(conn, 200) =~ "AWS EC2 Deployment Guide"
  end
end
