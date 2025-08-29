defmodule BoxwalletWeb.DiviLive do
  # import BoxWallet.App
  use BoxwalletWeb, :live_view
  alias Boxwallet.Coins.Divi

  def mount(_params, _session, socket) do
    socket = assign(socket, coin_name: "Divi", coin_title: "Crypto made easy!")
    {:ok, socket}
  end

  def handle_event("download_divi", _, socket) do
    IO.puts("Download Divi button clicked - Downloading to #{BoxWallet.App.home_folder()}")
    Divi.download_coin(BoxWallet.App.home_folder())
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <img src={~p"/images/divi_logo.png"} width="100"

      alt="Divi logo"
      class="h-100 w-100 rounded object-cover"
    />

    <h1><%= @coin_name %> Core Test Page</h1>
    <h2><%= @coin_title %></h2>
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
