defmodule Boxwallet.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BoxwalletWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:boxwallet, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Boxwallet.PubSub},
      # Start a worker by calling: Boxwallet.Worker.start_link(arg)
      # {Boxwallet.Worker, arg},
      # Start to serve requests, typically the last entry
      BoxwalletWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Boxwallet.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BoxwalletWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
