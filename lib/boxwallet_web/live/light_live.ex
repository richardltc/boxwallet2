defmodule BoxwalletWeb.LightLive do
  # import BoxWallet.App
  use BoxwalletWeb, :live_view
  alias Boxwallet.Coins.Divi

  def mount(_params, _session, socket) do
    socket = assign(socket, brightness: 10)
    {:ok, socket}
  end

  def handle_event("download_divi", _, socket) do
    IO.puts("Download Divi button clicked - Downloading to #{BoxWallet.App.home_folder()}")
    Divi.download_coin(BoxWallet.App.home_folder())
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <h1>Divi Core Test Page</h1>
    <%!-- <div id="light">
      <div class="meter">
        <span style={"width: #{@brightness}%"}>
          <%= assigns.brightness %>%
        </span>
      </div>
    </div> --%>
    <button phx-click="download_divi">Download Divi</button>
    """
  end
end
