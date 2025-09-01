defmodule BoxwalletWeb.DiviLive do
  # import BoxWallet.App
  use BoxwalletWeb, :live_view
  alias Boxwallet.Coins.Divi

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        coin_name: "Divi",
        coin_title: "The foundation for a truly decentralized future.",
        coin_description:
          "Our rapidly changing world requires flexible financial products. Through our innovative technology, we’re building the future of finance."
      )

    {:ok, socket}
  end

  def handle_event("download_divi", _, socket) do
    IO.puts("Download Divi button clicked - Downloading to #{BoxWallet.App.home_folder()}")
    Divi.download_coin(BoxWallet.App.home_folder())
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex justify-center items-center">
      <div class="card bg-base-100 w-full max-w-2xl shadow-xl p-8">
        <!-- Logo and title section -->
        <div class="flex flex-col md:flex-row items-start gap-6 mb-6">
          <img
            src={~p"/images/divi_logo.png"}
            alt="Divi logo"
            class="h-30 w-30 rounded-xl object-contain p-2"
          />
          <div class="flex-1">
            <div class="text-left">
              <h2 class="card-title text-3xl font-bold">{@coin_name}</h2>
              <p class="text-lg mt-2">{@coin_title}</p>
            </div>
          </div>
        </div>
        
    <!-- Description section -->
        <div class="text-center border-t border-gray-100 pt-6">
          <p class="text-gray-400 text-lg leading-relaxed max-w-2xl mx-auto">
            {@coin_description}
          </p>
        </div>
        
    <!-- Action buttons -->
        <div class="card-actions justify-center mt-8">
          <button class="btn btn-primary px-8">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="size-6"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5M16.5 12 12 16.5m0 0L7.5 12m4.5 4.5V3"
              />
            </svg>

            <i class="fas fa-download mr-2"></i>
            Install
          </button>

          <button class="btn btn-outline btn-secondary px-8">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="size-6"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="m3.75 13.5 10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75Z"
              />
            </svg>

            <i class="fas fa-info-circle mr-2"></i>
            Start
          </button>
          <button class="btn btn-outline btn-secondary px-8">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="size-6"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M11.412 15.655 9.75 21.75l3.745-4.012M9.257 13.5H3.75l2.659-2.849m2.048-2.194L14.25 2.25 12 10.5h8.25l-4.707 5.043M8.457 8.457 3 3m5.457 5.457 7.086 7.086m0 0L21 21"
              />
            </svg>

            <i class="fas fa-info-circle mr-2"></i>
            Stop
          </button>
        </div>
      </div>
    </div>
    """
  end
end
