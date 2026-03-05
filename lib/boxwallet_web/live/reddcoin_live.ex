defmodule BoxwalletWeb.ReddCoinLive do
  import BoxwalletWeb.CoreWalletToolbar
  import BoxwalletWeb.CoreWalletBalance
  import BoxwalletWeb.WalletBalanceDisplay
  import BoxwalletWeb.PromptModal
  import BoxwalletWeb.SyncProgress
  use Number
  use BoxwalletWeb, :live_view
  require Logger
  alias Boxwallet.Coins.ReddCoin

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Boxwallet.PubSub, "reddcoin:status")
    end

    # Seed initial state from GenServer
    server_state = ReddCoin.Server.get_state()

    socket =
      assign(socket,
        blockchain_is_synced: false,
        coin_name: "ReddCoin",
        coin_title: "The Original Social Currency.",
        coin_description:
          "With over 60,000 users in 50+ countries, Redd allows you to share, tip, and donate to anyone, anywhere on all major social media platforms.",
        show_install_alert: false,
        coin_files_exist: server_state.coin_files_exist,
        download_complete: server_state.download_complete,
        download_error: server_state.download_error,
        downloading: server_state.downloading,
        coin_daemon_starting: server_state.daemon_status == :starting,
        coin_daemon_started: server_state.daemon_status == :running,
        coin_daemon_stopping: server_state.daemon_status == :stopping,
        coin_daemon_stopped: server_state.daemon_status == :stopped,
        balance: server_state.balance,
        block_height: server_state.block_height,
        blocks_synced: server_state.blocks_synced,
        headers_synced: server_state.headers_synced,
        blocks: server_state.blocks,
        connections: server_state.connections,
        difficulty: server_state.difficulty,
        headers: server_state.headers,
        version: server_state.version,
        coin_auth: server_state.coin_auth,
        wallet_encryption_status: server_state.wallet_encryption_status,
        hide_balance: BoxWallet.Settings.get(:hide_balance),
        show_prompt: false,
        prompt_action: nil,
        prompt_answer: "",
        prompt_confirm: "",
        passwords_match: false
      )

    {:ok, socket}
  end

  # --- PubSub handler ---

  def handle_info({:reddcoin_state, state_map}, socket) do
    was_stopping = socket.assigns.coin_daemon_stopping
    socket = assign(socket, state_map)

    socket =
      if state_map[:coin_daemon_stopped] && was_stopping do
        Process.send_after(self(), :clear_flash, 4_000)
        put_flash(socket, :info, "#{socket.assigns.coin_name} Daemon stopped successfully.")
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  # --- UI Event Handlers ---

  def handle_event("toggle_hide_balance", _params, socket) do
    new_value = !socket.assigns.hide_balance
    BoxWallet.Settings.set(:hide_balance, new_value)
    {:noreply, assign(socket, :hide_balance, new_value)}
  end

  def handle_event("show_encrypt_prompt", _params, socket) do
    {:noreply,
     assign(socket,
       show_prompt: true,
       prompt_action: :encrypt,
       prompt_answer: "",
       prompt_confirm: "",
       passwords_match: false
     )}
  end

  def handle_event("show_unlock_prompt", _params, socket) do
    {:noreply, assign(socket, show_prompt: true, prompt_action: :unlock, prompt_answer: "")}
  end

  def handle_event("show_unlock_staking_prompt", _params, socket) do
    {:noreply,
     assign(socket, show_prompt: true, prompt_action: :unlock_for_staking, prompt_answer: "")}
  end

  def handle_event("validate_passwords", %{"answer" => p1, "answer_confirm" => p2}, socket) do
    {:noreply,
     assign(socket,
       prompt_answer: p1,
       prompt_confirm: p2,
       passwords_match: p1 != "" and p2 != "" and p1 == p2
     )}
  end

  def handle_event("lock_wallet", _params, socket) do
    {:ok, _coin_auth} = socket.assigns.coin_auth
    # TODO: ReddCoin.lock_wallet(coin_auth)
    {:noreply, socket}
  end

  def handle_event("prompt_submitted", %{"answer" => _password}, socket) do
    Process.send_after(self(), :clear_flash, 4000)

    {:ok, _coin_auth} = socket.assigns.coin_auth

    socket =
      case socket.assigns.prompt_action do
        :encrypt ->
          # TODO: ReddCoin.wallet_encrypt(coin_auth, password)
          IO.puts("Encrypting wallet...")
          socket

        :unlock ->
          # TODO: ReddCoin.wallet_unlock(coin_auth, password)
          IO.puts("Unlocking wallet...")
          socket

        :unlock_for_staking ->
          # TODO: ReddCoin.wallet_unlock_fs(coin_auth, password)
          IO.puts("Unlocking wallet for staking...")
          socket
      end

    {:noreply, assign(socket, show_prompt: false, prompt_action: nil)}
  end

  def handle_event("prompt_cancelled", _params, socket) do
    {:noreply,
     assign(socket,
       show_prompt: false,
       prompt_action: nil,
       prompt_answer: "",
       prompt_confirm: "",
       passwords_match: true
     )}
  end

  def handle_event("download_coin", _, socket) do
    ReddCoin.Server.download_coin()
    {:noreply, assign(socket, downloading: true, show_install_alert: true)}
  end

  def handle_event("start_coin_daemon", _, socket) do
    IO.puts("Attempting to start #{socket.assigns.coin_name} Daemon...")
    ReddCoin.Server.start_daemon()
    {:noreply, assign(socket, coin_daemon_starting: true, coin_daemon_stopped: false)}
  end

  def handle_event("stop_coin_daemon", _, socket) do
    IO.puts("Attempting to stop #{socket.assigns.coin_name} Daemon...")
    ReddCoin.Server.stop_daemon()

    Process.send_after(self(), :clear_flash, 4_000)

    {:noreply,
     socket
     |> put_flash(:info, "Stopping #{socket.assigns.coin_name} Daemon...")
     |> assign(:coin_daemon_stopping, true)
     |> assign(wallet_encryption_status: :wes_unknown)}
  end

  defp get_icon_state(name, assigns) do
    case name do
      :files ->
        %{
          name: "hero-arrow-down-tray",
          hint:
            if(assigns.coin_files_exist,
              do: "Core files exist",
              else: "Core files not downloaded"
            ),
          color: "text-rddred",
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

        %{name: "hero-face-smile", hint: hint, color: "text-rddred", state: state}

      :connections ->
        connections = assigns.connections

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

            _ ->
              "Connecting..."
          end

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
          color: "text-rddred",
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

            _ ->
              "Idle."
          end

        state =
          cond do
            assigns.coin_daemon_starting ->
              :disabled

            assigns.coin_daemon_started ->
              if connections > 0 and !assigns.blockchain_is_synced, do: :rotating, else: :enabled

            assigns.coin_daemon_stopped ->
              :disabled

            true ->
              :disabled
          end

        %{
          name: "hero-arrow-path",
          hint: hint,
          color: "text-rddred",
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
          color: "text-rddred",
          state: state
        }

      :staking ->
        %{name: "hero-bolt", hint: "Stats", color: "text-rddred", state: :disabled}
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
    <Layouts.app flash={@flash}>
      <.prompt_modal
        id="wallet-password"
        question={
          case @prompt_action do
            :encrypt -> "Enter a new password to encrypt your wallet:"
            :unlock -> "Enter your wallet password to unlock:"
            :unlock_for_staking -> "Enter your wallet password to unlock for staking:"
            _ -> "Enter your wallet password:"
          end
        }
        show_confirm={@prompt_action == :encrypt}
        on_change={if @prompt_action == :encrypt, do: "validate_passwords"}
        passwords_match={@passwords_match}
        answer_value={@prompt_answer}
        confirm_value={@prompt_confirm}
        icon="hero-lock-closed"
        show={@show_prompt}
        on_confirm="prompt_submitted"
        on_cancel="prompt_cancelled"
        input_type="password"
        placeholder="Enter password..."
      />
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
          <span>Downloading and installing ReddCoin... Please wait.</span>
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
        <div class="card bg-base-100 w-full max-w-6xl shadow-xl shadow-rddred/30 p-8">
          <!-- Logo and title section -->
          <div class="flex flex-col md:flex-row items-start gap-6 mb-6">
            <img
              src={~p"/images/rdd_logo.png"}
              alt="#{@coin_name} logo"
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

                  <.balance_display
                    balance={@balance}
                    hide_balance={@hide_balance}
                    color="text-rddred"
                  />
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
            <.sync_stats
              headers_synced={@headers_synced}
              blocks_synced={@blocks_synced}
              block_height={@block_height}
              color="text-rddred"
            />
          </div>
          
    <!-- Action buttons -->
          <div class="card-actions justify-center mt-8">
            <button
              class={
                if @coin_files_exist,
                  do: "btn btn-outline btn-boxwalletgreen px-8 disabled:opacity-40",
                  else: "btn btn-boxwalletgreen px-8 disabled:opacity-40"
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
                      phx-click="download_coin"
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
              class="btn btn-outline btn-boxwalletgreen px-8 disabled:opacity-40"
              phx-click="start_coin_daemon"
              disabled={!@coin_files_exist or !@coin_daemon_stopped}
              title={"Start #{@coin_name} Daemon"}
            >
              <span class="hero-play h-6 w-6" /> Start
            </button>

            <button
              class="btn btn-outline btn-boxwalletgreen px-8 disabled:opacity-40"
              phx-click="stop_coin_daemon"
              disabled={!@coin_daemon_started}
              title={"Stop #{@coin_name} Daemon"}
            >
              <span class="hero-stop h-6 w-6" /> Stop
            </button>

            <div class="dropdown dropdown-bottom">
              <button
                class="btn btn-outline btn-boxwalletgreen px-8 disabled:opacity-40"
                disabled={!@coin_daemon_started}
                phx-click={
                  case @wallet_encryption_status do
                    :wes_unencrypted -> "show_encrypt_prompt"
                    :wes_unlocked -> "lock_wallet"
                    :wes_unlocked_for_staking -> "lock_wallet"
                    _ -> nil
                  end
                }
              >
                <span class={
                  case @wallet_encryption_status do
                    :wes_unlocked -> "hero-lock-closed h-6 w-6"
                    :wes_unlocked_for_staking -> "hero-lock-closed h-6 w-6"
                    _ -> "hero-lock-open h-6 w-6"
                  end
                } /> {case @wallet_encryption_status do
                  :wes_unencrypted -> "Encrypt"
                  :wes_unlocked -> "Lock"
                  :wes_unlocked_for_staking -> "Lock"
                  _ -> "Unlock"
                end}
              </button>
              <%= if @wallet_encryption_status == :wes_locked do %>
                <ul
                  tabindex="-1"
                  class="dropdown-content menu bg-base-100 rounded-box z-1 w-52 p-2 shadow-sm"
                >
                  <li>
                    <a phx-click="show_unlock_prompt">
                      <span class="hero-lock-open h-5 w-5 inline-block" /> Unlock
                    </a>
                  </li>
                  <li>
                    <a phx-click="show_unlock_staking_prompt">
                      <span class="hero-bolt h-5 w-5 inline-block" />Unlock for staking
                    </a>
                  </li>
                </ul>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
