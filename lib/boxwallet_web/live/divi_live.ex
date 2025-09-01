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
    <div class="card bg-base-100 w-96 shadow-sm p-10">
      <img
        src={~p"/images/divi_logo.png"}
        alt="Divi logo"
        class="h-30 w-30 rounded object-cover"

      />
      <h2 class="card-title">{@coin_name} Core Test Page</h2>
      <p>
        A card component has a figure, a body part, and inside body there are title and actions parts
      </p>
      <div class="card-actions justify-end">
        <button class="btn btn-primary">Buy Now</button>
      </div>
    </div>
    <img
      src={~p"/images/divi_logo.png"}
      width="10"
      alt="Divi logo"
      class="h-10 w-10 rounded object-cover"
    />

    <h1>{@coin_name} Core Test Page</h1>
    <h2>{@coin_title}</h2>
    <%!-- <div id="light">
      <div class="meter">
        <span style={"width: #{@brightness}%"}>
          <%= assigns.brightness %>%
        </span>
      </div>
    </div> --%>
    <button class="btn">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="2.5"
        stroke="currentColor"
        class="size-[1.2em]"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z"
        />
      </svg>
      Like
    </button>
    <%!-- <button phx-click="download_divi">Download Divi</button> --%>
    """
  end
end
