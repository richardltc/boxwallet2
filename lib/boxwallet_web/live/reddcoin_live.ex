defmodule BoxwalletWeb.ReddCoinLive do
  # import BoxWallet.App
  use BoxwalletWeb, :live_view
  alias Boxwallet.Coins.ReddCoin

  def mount(_params, _session, socket) do
    socket = assign(socket, brightness: 10)
    {:ok, socket}
  end

  def handle_event("download_reddcoin", _, socket) do
    IO.puts("Download ReddCoin button clicked - Downloading to #{BoxWallet.App.home_folder()}")
    IO.inspect(ReddCoin.all_binary_files_exist(BoxWallet.App.home_folder()))
    ReddCoin.download_coin(BoxWallet.App.home_folder())
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <h1>ReddCoin Core Test Page</h1>
    <%!-- <div id="light">
      <div class="meter">
        <span style={"width: #{@brightness}%"}>
          <%= assigns.brightness %>%
        </span>
      </div>
    </div> --%>
    <button phx-click="download_reddcoin">Download ReddCoin</button>
    """
  end
end
