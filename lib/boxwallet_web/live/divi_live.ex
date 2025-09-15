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
          "Our rapidly changing world requires flexible financial products. Through our innovative technology, we’re building the future of finance.",
        show_install_alert: false
      )

    {:ok, socket}
  end

  def handle_event("download_divi", _, socket) do
    IO.puts("🚀 Starting download event")

    socket =
      socket
      |> assign(show_install_alert: true)
      |> assign_async(:download_result, fn ->
        IO.puts("🔄 Inside async function, about to call download_coin")
        result = Divi.download_coin(BoxWallet.App.home_folder())
        IO.puts("🏁 Async function completed")
        IO.inspect(result, label: "ASYNC FUNCTION RESULT")
        result
      end)

    {:noreply, socket}
  end

  def handle_async(:download_result, {:ok, result}, socket) do
    IO.puts("🎉 SUCCESS HANDLER CALLED: Download completed successfully")
    IO.inspect(result, label: "SUCCESS - Download result")

    socket =
      socket
      |> assign(show_install_alert: false)
      |> assign(download_complete: true)

    {:noreply, socket}
  end

  def handle_async(:download_result, {:error, reason}, socket) do
    IO.puts("❌ ERROR HANDLER CALLED: Download failed")
    IO.inspect(reason, label: "ERROR - Error reason")

    socket =
      socket
      |> assign(show_install_alert: false)
      |> assign(download_error: "Download failed: #{inspect(reason)}")

    {:noreply, socket}
  end

  def handle_async(:download_result, {:exit, reason}, socket) do
    IO.puts("💥 EXIT HANDLER CALLED: Download failed")
    IO.inspect(reason, label: "EXIT - Exit reason")

    socket =
      socket
      |> assign(show_install_alert: false)
      |> assign(download_error: "Download failed: #{inspect(reason)}")

    {:noreply, socket}
  end

  # Optional: Handle auto-hiding the alert
  def handle_info(:hide_install_alert, socket) do
    socket = assign(socket, :show_install_alert, false)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <!-- Alert (conditionally rendered) -->
    <%= if assigns[:show_install_alert] do %>
      <div role="alert" class="alert alert-info mb-4">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          class="h-6 w-6 shrink-0 stroke-current"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
          >
          </path>
        </svg>
        <span>Installation started successfully!</span>
      </div>
    <% end %>

    <%= if assigns[:download_complete] do %>
      <div role="alert" class="alert alert-success mb-4">
        <span>Download complete!</span>
      </div>
    <% end %>

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
          <button class="btn btn-primary px-8" onclick="install_modal.showModal()">
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
          
    <!-- DaisyUI Modal Dialog -->
          <dialog id="install_modal" class="modal">
            <div class="modal-box">
              <h3 class="font-bold text-lg">Confirm Installation</h3>
              <p class="py-4">Are you sure you want to proceed with the installation?</p>
              <div class="modal-action">
                <!-- Yes button -->
                <form method="dialog">
                  <button
                    class="btn btn-success mr-2"
                    phx-click="download_divi"
                    onclick="install_modal.close()"
                  >
                    Yes
                  </button>
                </form>
                <!-- No button -->
                <form method="dialog">
                  <button class="btn btn-error">No</button>
                </form>
              </div>
            </div>
          </dialog>

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
