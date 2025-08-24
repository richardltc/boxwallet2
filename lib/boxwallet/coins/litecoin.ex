# lib/my_app/coins/litecoin.ex
defmodule Boxwallet.Coins.Litecoin do
  @behaviour Boxwallet.CoinDaemon
  # Replace with actual URL
  @daemon_url "https://example.com/litecoind.tar.gz"
  @install_path Path.expand("~/.my_app/litecoin")
  @rpc_url "http://localhost:9332"
  @rpc_credentials [username: "rpcuser", password: "rpcpass"]
end
