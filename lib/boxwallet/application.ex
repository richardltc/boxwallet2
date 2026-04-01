defmodule Boxwallet.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  require Logger

  use Application

  @impl true
  def start(_type, _args) do
    # Make sure app directory exists
    Logger.info("#{BoxWallet.App.name()} v#{BoxWallet.App.version()} starting...")
    app_home_dir = BoxWallet.App.home_folder()
    Logger.info("Creating #{app_home_dir} if required")
    File.mkdir_p!(app_home_dir)

    children = [
      BoxwalletWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:boxwallet, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Boxwallet.PubSub},
      Boxwallet.Coins.ReddCoin.Server,
      Boxwallet.Coins.Divi.Server,
      Boxwallet.Coins.Litecoin.Server,
      Boxwallet.Coins.Zano.Server,
      # Start to serve requests, typically the last entry
      BoxwalletWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Boxwallet.Supervisor]
    result = Supervisor.start_link(children, opts)

    case result do
      {:ok, _pid} -> maybe_open_browser()
      _ -> :ok
    end

    result
  end

  defp maybe_open_browser do
    # Only open browser when running as a release
    if System.get_env("RELEASE_NAME") do
      port = Application.get_env(:boxwallet, BoxwalletWeb.Endpoint)[:http][:port] || 4000
      url = "http://localhost:#{port}"

      Task.start(fn ->
        # Small delay to ensure endpoint is fully ready
        Process.sleep(1000)

        case :os.type() do
          {:unix, :darwin} -> System.cmd("open", [url])
          {:unix, _} -> System.cmd("xdg-open", [url])
          {:win32, :nt} -> System.cmd("cmd", ["/c", "start", url])
        end
      end)
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BoxwalletWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
