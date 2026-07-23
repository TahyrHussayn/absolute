defmodule Absolute.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AbsoluteWeb.Telemetry,
      Absolute.Repo,
      {DNSCluster, query: Application.get_env(:absolute, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Absolute.PubSub},
      {Absolute.Counter, 0},
      Absolute.CrashWorker,
      # Start to serve requests, typically the last entry
      AbsoluteWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Absolute.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AbsoluteWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
