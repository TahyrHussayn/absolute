defmodule AbsoluteWeb.Router do
  use AbsoluteWeb, :router

  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AbsoluteWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AbsoluteWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/aws-guide", PageController, :aws_guide
    live "/playground", PlaygroundLive
    live "/cluster", ClusterLive
  end

  scope "/", AbsoluteWeb do
    pipe_through :api

    get "/metrics", MetricsController, :scrape
  end

  scope "/api", AbsoluteWeb do
    pipe_through :api

    get "/health", HealthController, :check
  end

  scope "/admin" do
    pipe_through :browser

    live_dashboard "/dashboard", metrics: AbsoluteWeb.Telemetry
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:absolute, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
