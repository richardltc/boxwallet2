defmodule BoxwalletWeb.DiviLive do
  # import BoxWallet.App
  import BoxwalletWeb.CoreWalletToolbar
  import BoxwalletWeb.CoreWalletBalance
  use Number
  use BoxwalletWeb, :live_view
  require Logger
  alias Boxwallet.Coins.Divi

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        blockchain_is_synced: false,
        coin_name: "Divi",
        coin_title: "The foundation for a truly decentralized future.",
        coin_description:
          "Our rapidly changing world requires flexible financial products. Through our innovative technology, we’re building the future of finance.",
        show_install_alert: false,
        coin_files_exist: Divi.files_exist(),
        download_complete: false,
        download_error: nil,
        downloading: false,
        coin_daemon_starting: false,
        coin_daemon_started: false,
        coin_daemon_stopping: false,
        coin_daemon_stopped: true,
        balance: 0.0,
        blocks: 0,
        connections: 0,
        difficulty: 0,
        headers: 0,
        version: "...",
        coin_auth: Divi.get_auth_values(),
        wallet_encryption_status: :wes_unknown
      )

    # 1. Always check connected? so it doesn't run twice (once for static, once for websocket)
    if connected?(socket) do
      send(self(), :verify_daemon_status)
    end

    # {:ok, coin_auth} = socket.assigns.coin_auth

    {:ok,
     socket
     |> assign(:coin_daemon_started, false)
     |> assign(:coin_daemon_stopped, true)
     |> assign(:checking_daemon, true)}
  end

  def handle_info(:verify_daemon_status, socket) do
    # 2. This runs "in the background" immediately after mount
    {:ok, coin_auth} = socket.assigns.coin_auth

    case Divi.daemon_is_running(coin_auth) do
      true ->
        IO.puts("#{socket.assigns.coin_name} Daemon is alive!")

        # 3. Trigger your specific info checks
        Process.send_after(self(), :check_get_info_status, 100)
        Process.send_after(self(), :check_get_blockchain_info_status, 200)
        Process.send_after(self(), :check_get_wallet_info_status, 300)
        Process.send_after(self(), :check_get_mn_sync_status, 400)

        {:noreply,
         socket
         |> assign(:coin_daemon_started, true)
         |> assign(:coin_daemon_stopped, false)
         |> assign(:checking_daemon, false)}

      false ->
        IO.puts("#{socket.assigns.coin_name} Daemon not running")
        {:noreply, assign(socket, :loading_daemon, false)}
    end
  end

  def handle_info(:check_get_blockchain_info_status, socket) do
    # Only keep checking if we think we are supposed to be starting/running
    if socket.assigns.coin_daemon_starting or socket.assigns.coin_daemon_started do
      {:ok, coin_auth} = socket.assigns.coin_auth

      case Divi.get_blockchain_info(coin_auth) do
        {:ok, response} ->
          socket =
            socket
            |> assign(:get_blockchain_info_response, response)
            |> assign(
              :blocks,
              Number.Delimit.number_to_delimited(response.result.blocks, precision: 0) || 0
            )
            |> assign(
              :difficulty,
              Number.Delimit.number_to_delimited(response.result.difficulty, precision: 0) || 0
            )
            |> assign(
              :headers,
              Number.Delimit.number_to_delimited(response.result.headers, precision: 0) || 0
            )

          # Process.send_after(self(), :check_get_blockchain_info_status, 2000)
          {:noreply, socket}

        {:error, _reason} ->
          IO.puts("#{socket.assigns.coin_name} Daemon not ready yet... retrying in 2s")

          Process.send_after(self(), :check_get_blockchain_info_status, 2000)

          {:noreply, socket}
      end
    else
      # If the user clicked "Stop" while it was booting, we stop polling.
      {:noreply, socket}
    end
  end

  def handle_info(:check_get_info_status, socket) do
    # Only keep checking if we think we are supposed to be starting/running
    if socket.assigns.coin_daemon_starting or socket.assigns.coin_daemon_started do
      {:ok, coin_auth} = socket.assigns.coin_auth

      case Divi.get_info(coin_auth) do
        {:ok, response} ->
          IO.puts("#{socket.assigns.coin_name} Daemon is alive!")

          socket =
            socket
            |> assign(:coin_daemon_starting, false)
            |> assign(:coin_daemon_started, true)
            |> assign(:getinfo_response, response)
            |> assign(:connections, response.result.connections || 0)
            |> assign(:version, response.result.version || "v...")
            |> put_flash(:info, "#{socket.assigns.coin_name} Daemon Started Successfully!")

          Process.send_after(self(), :check_get_info_status, 2000)
          Process.send_after(self(), :check_get_blockchain_info_status, 2000)
          Process.send_after(self(), :check_get_wallet_info_status, 2000)
          Process.send_after(self(), :check_get_mn_sync_status, 2000)
          {:noreply, socket}

        {:error, _reason} ->
          IO.puts("#{socket.assigns.coin_name} Daemon not ready yet... retrying in 2s")

          # 4. Failed (daemon still booting).
          # Schedule ANOTHER check for 2 seconds later.
          Process.send_after(self(), :check_get_info_status, 2000)

          {:noreply, socket}
      end
    else
      # If the user clicked "Stop" while it was booting, we stop polling.
      {:noreply, socket}
    end
  end

  def handle_info(:check_get_mn_sync_status, socket) do
    # Only keep checking if we think we are supposed to be starting/running
    if socket.assigns.coin_daemon_starting or socket.assigns.coin_daemon_started do
      {:ok, coin_auth} = socket.assigns.coin_auth

      case Divi.get_mn_sync_status(coin_auth) do
        {:ok, response} ->
          blockchain_is_synced = response.result.is_blockchain_synced

          socket =
            socket
            |> assign(:blockchain_is_synced, blockchain_is_synced)

          {:noreply, socket}

        {:error, _reason} ->
          IO.puts("⏳ Unable to get_mn_sync_status... retrying in 2s")

          Process.send_after(self(), :check_get_mn_sync_status, 2000)

          {:noreply, socket}
      end
    else
      # If the user clicked "Stop" while it was booting, we stop polling.
      {:noreply, socket}
    end
  end

  def handle_info(:check_get_wallet_info_status, socket) do
    # Only keep checking if we think we are supposed to be starting/running
    if socket.assigns.coin_daemon_starting or socket.assigns.coin_daemon_started do
      {:ok, coin_auth} = socket.assigns.coin_auth

      case Divi.get_wallet_info(coin_auth) do
        {:ok, response} ->
          wallet_encryption_status =
            case response.result.encryption_status do
              "unencrypted" ->
                :wes_unencrypted

              "unlocked" ->
                :wes_unlocked

              "locked" ->
                :wes_locked

              "unlocked-for-staking" ->
                :wes_unlocked_for_staking
            end

          socket =
            socket
            |> assign(:wallet_encryption_status, wallet_encryption_status)
            |> assign(:balance, response.result.balance)

          {:noreply, socket}

        {:error, _reason} ->
          IO.puts("⏳ Unable to get_wallet_info... retrying in 2s")

          Process.send_after(self(), :check_get_wallet_info_status, 2000)

          {:noreply, socket}
      end
    else
      # If the user clicked "Stop" while it was booting, we stop polling.
      {:noreply, socket}
    end
  end

  def handle_event("download_divi", _, socket) do
    IO.puts("🚀 Starting download event")

    # Set the loading state
    socket = assign(socket, downloading: true, show_install_alert: true)

    # Send a message to self to perform the download
    # This keeps the UI responsive while downloading
    send(self(), :perform_download)

    {:noreply, socket}
  end

  def handle_event("start_coin_daemon", _, socket) do
    IO.puts("Attempting to start #{socket.assigns.coin_name} Daemon...")
    {:ok, coin_auth} = socket.assigns.coin_auth

    socket =
      case Divi.start_daemon() do
        {:ok} ->
          IO.puts("#{socket.assigns.coin_name} Starting...")
          # assign(socket, coin_daemon_started: true, coin_daemon_stopped: false)
          socket =
            socket
            |> assign(:coin_daemon_starting, true)
            |> assign(:coin_daemon_started, false)
            |> assign(:coin_daemon_stopped, false)

          IO.puts("Calling getinfo...")
          # Send a message to 'self' to check status in 2000ms
          Process.send_after(self(), :check_get_info_status, 2000)

          {:noreply, socket}

        {:error, reason} ->
          Logger.error("Failed to start #{reason}")

          socket =
            socket
            |> put_flash(:error, "Could not start daemon: #{inspect(reason)}")
            |> assign(:coin_daemon_started, false)

          {:noreply, socket}
      end
  end

  def handle_event("stop_coin_daemon", _, socket) do
    {:ok, coin_auth} = socket.assigns.coin_auth

    IO.puts("Attempting to stop #{socket.assigns.coin_name} Daemon...")

    parent = self()

    spawn(fn ->
      result = Divi.stop_daemon(coin_auth)
      send(parent, {:daemon_stop_result, result})
    end)

    {:noreply,
     socket
     |> put_flash(:info, "Stopping daemon...")
     |> assign(:coin_daemon_stopping, true)
     |> assign(wallet_encryption_status: :wes_unknown)}
  end

  def handle_info(:perform_download, socket) do
    IO.puts("🔄 Performing download")

    case Divi.download_coin() do
      {:ok} ->
        IO.puts("#{socket.assigns.coin_name} Download completed successfully")

        socket =
          socket
          |> assign(downloading: false)
          |> assign(show_install_alert: false)
          |> assign(download_complete: true)
          |> assign(coin_files_exist: true)
          |> assign(download_error: nil)

        # Auto-hide success message after 5 seconds..
        Process.send_after(self(), :hide_success_message, 5000)

        {:noreply, socket}

      {:error, reason} ->
        IO.puts("#{socket.assigns.coin_name} Download failed")
        IO.inspect(reason, label: "ERROR - Error reason")

        socket =
          socket
          |> assign(downloading: false)
          |> assign(show_install_alert: false)
          |> assign(download_complete: false)
          |> assign(download_error: "Download failed: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  def handle_info(:hide_success_message, socket) do
    socket = assign(socket, download_complete: false)
    {:noreply, socket}
  end

  def handle_info({:daemon_stop_result, {:ok, _response}}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "#{socket.assigns.coin_name} Daemon stopped successfully")
     |> assign(:coin_daemon_starting, false)
     |> assign(:coin_daemon_started, false)
     |> assign(:coin_daemon_stopped, true)
     |> assign(:connections, 0)
     |> assign(:blocks, 0)
     |> assign(:headers, 0)
     |> assign(:difficulty, 0)
     |> assign(:coin_daemon_stopping, true)
     |> assign(:daemon_status, :stopped)}
  end

  def handle_info({:daemon_stop_result, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "Failed to stop daemon: #{inspect(reason)}")
     |> assign(:daemon_stopping, false)}
  end

  defp get_icon_state(name, assigns) do
    case name do
      :files ->
        %{
          name: "hero-arrow-down-tray",
          # "Core files",
          hint:
            if(assigns.coin_files_exist,
              do: "Core files exist",
              else: "Core files not downloaded"
            ),
          color: "text-red-400",
          state: if(assigns.coin_files_exist, do: :enabled, else: :disabled)
        }

      :daemon ->
        state =
          cond do
            assigns.coin_daemon_starting -> :flashing
            assigns.coin_daemon_started -> :enabled
            assigns.coin_daemon_stopped -> :disabled
            true -> :disabled
          end

        hint =
          cond do
            assigns.coin_daemon_starting -> "Daemon starting..."
            assigns.coin_daemon_started -> "Daemon running"
            assigns.coin_daemon_stopped -> "Daemon stopped"
            true -> "Idle"
          end

        %{name: "hero-face-smile", hint: hint, color: "text-red-400", state: state}

      :connections ->
        connections = assigns.connections

        # Determine the hint text based on the connection count.
        hint =
          case connections do
            0 ->
              if !assigns.coin_daemon_stopped do
                "Searching for connections..."
              else
                "Idle"
              end

            _ when connections > 0 ->
              "#{connections} connections"

            # Fallback for unexpected values like -1, etc.
            _ ->
              "Connecting..."

              # 0 -> "Waiting for connections..."
              # _ when connections > 0 -> "#{connections} connections"
              # # Fallback for unexpected values like -1, etc.
              # _ -> "Connecting..."
          end

        # state = if connections > 0, do: :enabled, else: :disabled
        state =
          case connections do
            0 ->
              if assigns.coin_daemon_started do
                :flashing
              else
                :disabled
              end

            _ when connections > 0 ->
              :enabled

            _ ->
              :disabled
          end

        %{
          name: "hero-signal",
          hint: hint,
          color: "text-red-400",
          state: state
        }

      :syncing ->
        connections = assigns.connections

        hint =
          case connections do
            0 ->
              if !assigns.coin_daemon_stopped do
                "Waiting for connections..."
              else
                "Idle"
              end

            _ when connections > 0 ->
              "Syncing..."

            # Fallback for unexpected values like -1, etc.
            _ ->
              "Idle."
          end

        state =
          cond do
            assigns.coin_daemon_starting ->
              :disabled

            assigns.coin_daemon_started ->
              if connections > 0 and !assigns.blockchain_is_synced, do: :rotating, else: :enabled

            # assigns.coin_daemon_started -> if connections > 0, do: :rotating
            assigns.coin_daemon_stopped ->
              :disabled

            true ->
              :disabled
          end

        %{
          name: "hero-arrow-path",
          hint: hint,
          color: "text-red-400",
          state: state
        }

      :encryption ->
        hint =
          cond do
            assigns.wallet_encryption_status == :wes_unencrypted ->
              "Wallet unencrypted! Please encrypt NOW!"

            assigns.wallet_encryption_status == :wes_unlocked ->
              "Wallet unlocked!"

            assigns.wallet_encryption_status == :wes_locked ->
              "Wallet locked"

            assigns.wallet_encryption_status == :wes_unlocked_for_staking ->
              "Wallet unlocked for staking :)"

            assigns.wallet_encryption_status == :wes_unknown ->
              "Wallet encryption unknown."
          end

        state =
          cond do
            assigns.wallet_encryption_status == :wes_unencrypted ->
              :pulsing

            assigns.wallet_encryption_status == :wes_unlocked ->
              :enabled

            assigns.wallet_encryption_status == :wes_locked ->
              :enabled

            assigns.wallet_encryption_status == :wes_unlocked_for_staking ->
              :enabled

            assigns.wallet_encryption_status == :wes_unknown ->
              :disabled
          end

        name =
          if assigns.wallet_encryption_status == :wes_locked do
            "hero-lock-closed"
          else
            "hero-lock-open"
          end

        %{
          name: name,
          hint: hint,
          color: "text-red-400",
          state: state
        }

      :staking ->
        %{name: "hero-bolt", hint: "Stats", color: "text-red-400", state: :disabled}

        # ... add other icons here
    end
  end

  def render(assigns) do
    icon_list = [
      get_icon_state(:files, assigns),
      get_icon_state(:daemon, assigns),
      get_icon_state(:connections, assigns),
      get_icon_state(:syncing, assigns),
      get_icon_state(:encryption, assigns),
      get_icon_state(:staking, assigns)
    ]

    assigns = assign(assigns, :icons, icon_list)

    ~H"""
    <!-- Download in progress alert -->
    <%= if @downloading do %>
      <div role="alert" class="alert alert-info mb-4">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          class="h-6 w-6 shrink-0 stroke-current animate-spin"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
          />
        </svg>
        <span>Downloading and installing Divi... Please wait.</span>
      </div>
    <% end %>

    <!-- Success alert -->
    <%= if @download_complete do %>
      <div role="alert" class="alert alert-success mb-4">
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
            d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
        <span>Download and installation completed successfully!</span>
      </div>
    <% end %>

    <!-- Error alert -->
    <%= if @download_error do %>
      <div role="alert" class="alert alert-error mb-4">
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
            d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
        <span>{@download_error}</span>
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
              <h2 class="card-title text-3xl font-bold items-baseline flex justify-between">
                <div class="flex items-baseline">
                  {@coin_name}
                  <small class="badge badge-sm ml-1 font-mono border-0">
                    v{@version}
                  </small>
                </div>

                <div class="flex items-baseline">
                  <span class="text-lg font-normal text-gray-500 mr-1">
                    Balance:
                  </span>

                  <small class="badge text-3xl font-mono border-0">
                    {@balance}
                  </small>
                </div>
              </h2>
              <p class="text-lg mt-2 mb-4">{@coin_title}</p>

              <.hero_icons_row icons={@icons} />
            </div>
          </div>
        </div>
        
    <!-- Description section -->
        <div class="text-center border-t border-gray-100 pt-6">
          <p class="text-gray-400 text-lg leading-relaxed max-w-2xl mx-auto">
            {@coin_description}
          </p>
          <div class="stats shadow mt-3">
            <div class="stat place-items-center">
              <div class="stat-title">Headers</div>
              <div class="stat-value text-2xl">{@headers}</div>
              <%!-- <div class="stat-desc">Headers</div> --%>
            </div>

            <div class="stat place-items-center">
              <div class="stat-title">Blocks</div>
              <div class="stat-value text-2xl">{@blocks}</div>
              <%!-- <div class="stat-value text-secondary">{@blocks}</div> --%>
              <%!-- <div class="stat-desc text-secondary">↗︎ 40 (2%)</div> --%>
            </div>

            <div class="stat place-items-center">
              <div class="stat-title">Difficulty</div>
              <div class="stat-value text-2xl">{@difficulty}</div>
              <%!-- <div class="stat-desc">↘︎ 90 (14%)</div> --%>
            </div>
          </div>
        </div>
        
    <!-- Action buttons -->
        <div class="card-actions justify-center mt-8">
          <button
            class={
              if @coin_files_exist,
                do: "btn btn-outline btn-secondary px-8",
                else: "btn btn-primary px-8"
            }
            onclick="install_modal.showModal()"
            disabled={@downloading}
            title={
              if @coin_files_exist,
                do: "Update existing #{@coin_name} core files",
                else: "Install #{@coin_name} core files"
            }
          >
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
            {if @coin_files_exist, do: "Update", else: "Install"}
          </button>
          <!-- DaisyUI Modal Dialog -->
          <dialog id="install_modal" class="modal">
            <div class="modal-box">
              <h3 class="font-bold text-lg">Confirm Installation</h3>
              <p class="py-4">Are you sure you want to install the {@coin_name} core files?</p>
              <div class="modal-action">
                <!-- Yes button -->
                <form method="dialog">
                  <button
                    class="btn btn-success mr-2"
                    phx-click="download_divi"
                    onclick="install_modal.close()"
                    disabled={@downloading}
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

          <button
            class="btn btn-outline btn-secondary px-8"
            phx-click="start_coin_daemon"
            disabled={!@coin_files_exist or !@coin_daemon_stopped}
            title={"Start #{@coin_name} Daemon"}
          >
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
            Start
          </button>

          <button
            class="btn btn-outline btn-secondary px-8"
            phx-click="stop_coin_daemon"
            title={"Stop #{@coin_name} Daemon"}
          >
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
            Stop
          </button>
        </div>
      </div>
    </div>
    """
  end
end
