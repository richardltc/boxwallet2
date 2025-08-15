# lib/my_app/coin_daemon.ex
defmodule BoxWallet.CoinDaemon do
  @callback install_daemon() :: :ok | {:error, String.t()}
  @callback start_daemon() :: :ok
  @callback stop_daemon() :: :ok
  @callback daemon_running?() :: boolean
  @callback get_sync_info() :: %{blocks: integer, headers: integer, progress: integer}
end
