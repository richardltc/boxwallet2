defmodule BoxwalletWeb.LitecoinLive do
  import BoxwalletWeb.CoreWalletToolbar
  import BoxwalletWeb.CoreWalletBalance
  import BoxwalletWeb.WalletBalanceDisplay
  import BoxwalletWeb.PromptModal
  import BoxwalletWeb.SyncProgress
  import BoxwalletWeb.CoinSidebar
  import BoxwalletWeb.CoinHomeSection
  import BoxwalletWeb.CoinTransactions
  import BoxwalletWeb.CoinSend
  import BoxwalletWeb.CoinSettings
  import BoxwalletWeb.ReceiveAddressModal
  use Number
  use BoxwalletWeb, :live_view
  require Logger
  alias Boxwallet.Coins.Litecoin

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Boxwallet.PubSub, "litecoin:status")
      Litecoin.Server.resume_polling()
    end

    # Seed initial state from GenServer
    server_state = Litecoin.Server.get_state()

    socket =
      assign(socket,
        blockchain_is_synced: server_state.blockchain_is_synced,
        coin_name: "Litecoin",
        coin_name_abbrev: Litecoin.coin_name_abbrev(),
        coin_title:
          "Litecoin (LTC) — a peer-to-peer cryptocurrency for fast, low-cost payments.",
        coin_description:
          "Launched in 2011 by Charlie Lee, Litecoin is one of the earliest Bitcoin alternatives. It uses a Scrypt proof-of-work algorithm, enabling faster block generation times of approximately 2.5 minutes compared to Bitcoin's 10 minutes. Designed for everyday transactions, Litecoin offers lower fees and quicker confirmations, making it well-suited for point-of-sale payments and smaller transfers.",
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
        unconfirmed_balance: server_state.unconfirmed_balance,
        immature_balance: server_state.immature_balance,
        block_height: server_state.block_height,
        blocks_synced: server_state.blocks_synced,
        headers_synced: server_state.headers_synced,
        blocks: server_state.blocks,
        connections: server_state.connections,
        difficulty: server_state.difficulty,
        headers: server_state.headers,
        version: Boxwallet.Coins.Litecoin.core_version(),
        coin_auth: server_state.coin_auth,
        staking: server_state.staking,
        wallet_encryption_status: server_state.wallet_encryption_status,
        hide_balance: BoxWallet.Settings.get(:hide_balance),
        show_prompt: false,
        prompt_action: nil,
        prompt_answer: "",
        prompt_confirm: "",
        passwords_match: false,
        active_tab: :home,
        transactions: server_state.transactions,
        testnet_enabled: testnet_enabled?(Litecoin),
        show_receive_modal: false,
        receive_address: ""
      )

    {:ok, socket}
  end

  def terminate(_reason, _socket) do
    Litecoin.Server.pause_polling()
    :ok
  end

  # --- PubSub handler ---

  def handle_info({:litecoin_state, state_map}, socket) do
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

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    tab = String.to_existing_atom(tab)
    Litecoin.Server.set_active_tab(tab)
    {:noreply, assign(socket, :active_tab, tab)}
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
    # TODO: Litecoin.lock_wallet(coin_auth)
    {:noreply, socket}
  end

  def handle_event("prompt_submitted", %{"answer" => password}, socket) do
    Process.send_after(self(), :clear_flash, 4000)

    {:ok, coin_auth} = socket.assigns.coin_auth

    socket =
      case socket.assigns.prompt_action do
        :encrypt ->
          case Litecoin.wallet_encrypt(coin_auth, password) do
            :ok ->
              socket
              |> put_flash(:info, "Wallet encrypted successfully.")
              |> assign(wallet_encryption_status: :wes_locked)

            {:error, reason} ->
              put_flash(socket, :error, "Encryption failed: #{reason}")
          end

        :unlock ->
          case Litecoin.wallet_unlock(coin_auth, password) do
            :ok ->
              socket
              |> put_flash(:info, "Wallet unlocked successfully.")
              |> assign(wallet_encryption_status: :wes_unlocked)

            {:error, reason} ->
              put_flash(socket, :error, "Unable to unlock wallet: #{reason}")
          end

        :unlock_for_staking ->
          case Litecoin.wallet_unlock_fs(coin_auth, password) do
            :ok ->
              socket
              |> put_flash(:info, "Wallet unlocked for staking successfully.")
              |> assign(wallet_encryption_status: :wes_unlocked_for_staking)

            {:error, reason} ->
              put_flash(socket, :error, "Unable to unlock wallet: #{reason}")
          end
      end

    {:noreply, assign(socket, show_prompt: false, prompt_action: nil)}
  end

  def handle_event("receive_address", _params, socket) do
    case socket.assigns.coin_auth do
      {:ok, auth} ->
        case Litecoin.get_new_address(auth) do
          {:ok, %{result: address}} when is_binary(address) ->
            {:noreply, assign(socket, show_receive_modal: true, receive_address: address)}

          {:error, reason} ->
            Logger.error("Failed to get new address: #{inspect(reason)}")

            {:noreply,
             socket
             |> put_flash(:error, "Failed to get a new receive address.")
             |> then(fn s ->
               Process.send_after(self(), :clear_flash, 4_000)
               s
             end)}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Daemon not available.")}
    end
  end

  def handle_event("close_receive_modal", _params, socket) do
    {:noreply, assign(socket, show_receive_modal: false)}
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
    Litecoin.Server.download_coin()
    {:noreply, assign(socket, downloading: true, show_install_alert: true)}
  end

  def handle_event("start_coin_daemon", _, socket) do
    IO.puts("Attempting to start #{socket.assigns.coin_name} Daemon...")
    Litecoin.Server.start_daemon()
    {:noreply, assign(socket, coin_daemon_starting: true, coin_daemon_stopped: false)}
  end

  def handle_event("stop_coin_daemon", _, socket) do
    IO.puts("Attempting to stop #{socket.assigns.coin_name} Daemon...")
    Litecoin.Server.stop_daemon()

    Process.send_after(self(), :clear_flash, 4_000)

    {:noreply,
     socket
     |> put_flash(:info, "Stopping #{socket.assigns.coin_name} Daemon...")
     |> assign(:coin_daemon_stopping, true)
     |> assign(wallet_encryption_status: :wes_unknown)}
  end

  def handle_event("confirm_toggle_testnet", _params, socket) do
    new_value = !socket.assigns.testnet_enabled
    conf_file = Litecoin.get_conf_file_location()

    if new_value do
      BoxWallet.Coins.ConfigManager.enable_testnet(conf_file)
    else
      BoxWallet.Coins.ConfigManager.disable_testnet(conf_file)
    end

    Process.send_after(self(), :clear_flash, 4_000)

    if socket.assigns.coin_daemon_started do
      Litecoin.Server.stop_daemon()

      {:noreply,
       socket
       |> assign(testnet_enabled: new_value, coin_daemon_stopping: true)
       |> put_flash(:info, "Testnet #{if new_value, do: "enabled", else: "disabled"}. Stopping #{socket.assigns.coin_name} Daemon...")}
    else
      {:noreply,
       socket
       |> assign(testnet_enabled: new_value)
       |> put_flash(:info, "Testnet #{if new_value, do: "enabled", else: "disabled"}. Restart the daemon for changes to take effect.")}
    end
  end

  defp testnet_enabled?(coin_module) do
    case BoxWallet.Coins.ConfigManager.get_label_value(coin_module.get_conf_file_location(), "testnet") do
      {:ok, "1"} -> true
      _ -> false
    end
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
          color: "text-litecoinblue",
          state: if(assigns.coin_files_exist, do: :enabled, else: :disabled)
        }

      :daemon ->
        state =
          cond do
            assigns.coin_daemon_starting -> :pulsing
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

        %{name: "hero-face-smile", hint: hint, color: "text-litecoinblue", state: state}

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
                :pulsing
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
          color: "text-litecoinblue",
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
          color: "text-litecoinblue",
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
          color: "text-litecoinblue",
          state: state
        }

      :staking ->
        hint =
          if assigns.staking do
            "Staking Active :)"
          else
            "Staking not active"
          end

        state =
          if assigns.staking do
            :pulsing
          else
            :disabled
          end

        %{name: "hero-bolt", hint: hint, color: "text-litecoinblue", state: state}
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
      <.receive_address_modal
        id="receive-address"
        show={@show_receive_modal}
        address={@receive_address}
        on_close="close_receive_modal"
        color="text-litecoinblue"
      />
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
          <span>Downloading and installing Litecoin... Please wait.</span>
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

      <div class="flex justify-center items-start gap-4">
        <.coin_sidebar color="text-litecoinblue" active_tab={@active_tab} />
        <div class="card bg-base-200 w-full max-w-6xl shadow-xl shadow-litecoinblue/30 p-8">
          <!-- Logo and title section -->
          <div class="flex flex-col md:flex-row items-start gap-6 mb-6">
            <img
              src={~p"/images/litecoin_logo.png"}
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
                    unconfirmed_balance={@unconfirmed_balance}
                    immature_balance={@immature_balance}
                    hide_balance={@hide_balance}
                    color="text-litecoinblue"
                  />
                </h2>
                <p class="text-lg mt-2 mb-4">{@coin_title}</p>

                <.hero_icons_row icons={@icons} />
              </div>
            </div>
          </div>

          <%= case @active_tab do %>
            <% :home -> %>
              <.coin_home_section
                coin_name={@coin_name}
                coin_description={@coin_description}
                headers_synced={@headers_synced}
                blocks_synced={@blocks_synced}
                block_height={@block_height}
                color="text-litecoinblue"
                coin_files_exist={@coin_files_exist}
                downloading={@downloading}
                download_complete={@download_complete}
                download_error={@download_error}
                coin_daemon_started={@coin_daemon_started}
                coin_daemon_stopped={@coin_daemon_stopped}
                wallet_encryption_status={@wallet_encryption_status}
                on_download="download_coin"
              />
            <% :settings -> %>
              <.coin_settings
                coin_name={@coin_name}
                color="text-litecoinblue"
                testnet_enabled={@testnet_enabled}
                coin_files_exist={@coin_files_exist}
                downloading={@downloading}
                download_complete={@download_complete}
                download_error={@download_error}
                on_update="download_coin"
              />
            <% :receive -> %>
              <.coin_transactions color="text-litecoinblue" coin_daemon_started={@coin_daemon_started} transactions={@transactions} />
            <% :send -> %>
              <.coin_send color="text-litecoinblue" coin_daemon_started={@coin_daemon_started} coin_name_abbrev={@coin_name_abbrev} />
            <% _ -> %>
              <.coin_transactions color="text-litecoinblue" coin_daemon_started={@coin_daemon_started} transactions={@transactions} />
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
