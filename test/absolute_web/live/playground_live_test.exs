defmodule AbsoluteWeb.PlaygroundLiveTest do
  use AbsoluteWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  test "renders playground page with title and initial stats", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/playground")
    assert html =~ "Complete BEAM Feature Playground"
    assert has_element?(view, "#counter-value")
  end

  test "increments and decrements counter", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/playground")

    assert view |> element("#counter-value") |> render() =~ "0"

    view |> element("#inc-counter-btn") |> render_click()
    assert view |> element("#counter-value") |> render() =~ "1"

    view |> element("#dec-counter-btn") |> render_click()
    assert view |> element("#counter-value") |> render() =~ "0"
  end

  test "spawns processes and updates results", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/playground")

    view |> element("#spawn-10k-btn") |> render_click()

    assert render(view) =~ "Executing concurrent processes" or render(view) =~ "10000"
  end

  test "crashes worker and recovers", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/playground")

    html = view |> element("#crash-worker-btn") |> render_click()
    assert html =~ "Total Restarts"
  end

  test "interacts with ETS leaderboard and Agent", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/playground")

    # Agent increment
    view |> element("button[phx-click='inc_agent'][phx-value-color='red']") |> render_click()
    assert render(view) =~ "RED"

    # Stream fibonacci
    view |> element("button[phx-click='run_fib_stream'][phx-value-count='10']") |> render_click()
    assert render(view) =~ "Computed 10 numbers"
  end
end
