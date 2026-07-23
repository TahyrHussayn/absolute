defmodule AbsoluteWeb.ClusterLiveTest do
  use AbsoluteWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders cluster live page with node status", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/cluster")
    assert html =~ "Multi-Node Distributed BEAM Cluster"
    assert has_element?(view, "#cluster-messages")
  end

  test "sends cross-node broadcast message", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/cluster")

    view
    |> form("form[phx-submit='send_cross_node']", %{"message" => "Hello Cluster!"})
    |> render_submit()

    assert render(view) =~ "Hello Cluster!"
  end
end
