defmodule BoxwalletWeb.PivxLive do
  import BoxwalletWeb.CoreWalletToolbar
  import BoxwalletWeb.WalletBalanceDisplay
  import BoxwalletWeb.PromptModal
  import BoxwalletWeb.CoinSidebar
  import BoxwalletWeb.CoinHomeSection
  import BoxwalletWeb.CoinTransactions
  import BoxwalletWeb.CoinReceive
  import BoxwalletWeb.CoinSend
  import BoxwalletWeb.CoinSettings

  use Number
  use BoxwalletWeb, :live_view
  require Logger
  alias Boxwallet.Coins.Pivx

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Boxwallet.PubSub, "pivx:status")
      Pivx.Server.resume_polling()
    end

    # Seed initial state from GenServer
    server_state = Pivx.Server.get_state()

    socket =
      assign(socket,
        blockchain_is_synced: server_state.blockchain_is_synced,
        coin_name: "PIVX",
        coin_name_abbrev: Pivx.coin_name_abbrev(),
        coin_title:
          "PIVX (PIVX) — a privacy-focused, community-governed cryptocurrency with proof-of-stake.",
        coin_description:
          "PIVX is a privacy-focused decentralized open-source cryptocurrency with proof-of-stake consensus. It features a community-governed treasury system, shield (zk-SNARKs) privacy protocol, and fast transactions. PIVX empowers users with financial freedom through advanced privacy features and decentralized governance.",
        show_install_alert: false,
        coin_files_exist: server_state.coin_files_exist,
        download_complete: server_state.download_complete,
        download_error: server_state.download_error,
        downloading: server_state.downloading,
        fetching_params: server_state.fetching_params,
        fetching_params_complete: server_state.fetching_params_complete,
        fetching_params_error: server_state.fetching_params_error,
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
        verification_progress: server_state.verification_progress,
        daemon_warmup_status: server_state.daemon_warmup_status,
        blocks: server_state.blocks,
        connections: server_state.connections,
        difficulty: server_state.difficulty,
        headers: server_state.headers,
        version: Pivx.core_version(),
        coin_auth: server_state.coin_auth,
        wallet_encryption_status: server_state.wallet_encryption_status,
        hide_balance: BoxWallet.Settings.get(:hide_balance),
        show_prompt: false,
        prompt_action: nil,
        prompt_answer: "",
        prompt_confirm: "",
        passwords_match: false,
        active_tab: :home,
        transactions: [],
        disk_used_bytes: server_state.disk_used_bytes,
        disk_total_bytes: server_state.disk_total_bytes,
        testnet_enabled: testnet_enabled?(Pivx),
        pruning_enabled: pruning_enabled?(Pivx),
        prune_size: get_prune_size(Pivx),
        receive_address: "",
        send_address: "",
        address_valid: :empty,
        pending_send_address: nil,
        pending_send_amount: nil
      )

    {:ok, socket}
  end

  # --- PubSub handler ---

  def handle_info({:pivx_state, state_map}, socket) do
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
    Pivx.Server.set_active_tab(tab)
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("show_encrypt_prompt", _params, socket) do
    Process.send_after(self(), :clear_flash, 4_000)
    {:noreply, put_flash(socket, :info, "Wallet encryption coming soon.")}
  end

  def handle_event("show_unlock_prompt", _params, socket) do
    Process.send_after(self(), :clear_flash, 4_000)
    {:noreply, put_flash(socket, :info, "Wallet unlock coming soon.")}
  end

  def handle_event("validate_passwords", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("prompt_submitted", _params, socket) do
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
    Pivx.Server.download_coin()
    {:noreply, assign(socket, downloading: true, show_install_alert: true)}
  end

  def handle_event("start_coin_daemon", _, socket) do
    Process.send_after(self(), :clear_flash, 4_000)
    {:noreply, put_flash(socket, :info, "Start daemon coming soon.")}
  end

  def handle_event("stop_coin_daemon", _, socket) do
    Process.send_after(self(), :clear_flash, 4_000)
    {:noreply, put_flash(socket, :info, "Stop daemon coming soon.")}
  end

  def handle_event("confirm_toggle_testnet", _params, socket) do
    new_value = !socket.assigns.testnet_enabled
    conf_file = Pivx.get_conf_file_location()

    if new_value do
      BoxWallet.Coins.ConfigManager.enable_testnet(conf_file)
    else
      BoxWallet.Coins.ConfigManager.disable_testnet(conf_file)
    end

    Process.send_after(self(), :clear_flash, 4_000)

    if socket.assigns.coin_daemon_started do
      Pivx.Server.stop_daemon()

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

  def handle_event("stage_prune_size", %{"prune_size" => size_str}, socket) do
    case Integer.parse(size_str) do
      {n, _} when n >= 600 -> {:noreply, assign(socket, :prune_size, n)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("confirm_toggle_pruning", _params, socket) do
    new_enabled = !socket.assigns.pruning_enabled
    conf_file = Pivx.get_conf_file_location()

    if new_enabled do
      BoxWallet.Coins.ConfigManager.enable_pruning(conf_file, socket.assigns.prune_size)
    else
      BoxWallet.Coins.ConfigManager.disable_pruning(conf_file)
    end

    Process.send_after(self(), :clear_flash, 4_000)

    if socket.assigns.coin_daemon_started do
      Pivx.Server.stop_daemon()

      {:noreply,
       socket
       |> assign(pruning_enabled: new_enabled, coin_daemon_stopping: true)
       |> put_flash(:info, "Pruning #{if new_enabled, do: "enabled", else: "disabled"}. Stopping #{socket.assigns.coin_name} Daemon...")}
    else
      {:noreply,
       socket
       |> assign(pruning_enabled: new_enabled)
       |> put_flash(:info, "Pruning #{if new_enabled, do: "enabled", else: "disabled"}. Restart the daemon for changes to take effect.")}
    end
  end

  def handle_event("confirm_update_prune_size", _params, socket) do
    conf_file = Pivx.get_conf_file_location()
    BoxWallet.Coins.ConfigManager.enable_pruning(conf_file, socket.assigns.prune_size)

    Process.send_after(self(), :clear_flash, 4_000)

    if socket.assigns.coin_daemon_started do
      Pivx.Server.stop_daemon()

      {:noreply,
       socket
       |> assign(coin_daemon_stopping: true)
       |> put_flash(:info, "Prune size set to #{socket.assigns.prune_size} MB. Stopping #{socket.assigns.coin_name} Daemon...")}
    else
      {:noreply,
       put_flash(socket, :info, "Prune size set to #{socket.assigns.prune_size} MB. Restart the daemon for changes to take effect.")}
    end
  end

  def handle_event("validate_send_address", %{"address" => _address}, socket) do
    # TODO: implement address validation
    {:noreply, socket}
  end

  def handle_event("send_coin", _params, socket) do
    # TODO: implement send
    {:noreply, socket}
  end

  def handle_event("new_receive_address", _params, socket) do
    # TODO: implement new receive address
    {:noreply, socket}
  end

  def handle_event("lock_wallet", _params, socket) do
    Process.send_after(self(), :clear_flash, 4_000)
    {:noreply, put_flash(socket, :info, "Wallet lock coming soon.")}
  end

  defp testnet_enabled?(coin_module) do
    case BoxWallet.Coins.ConfigManager.get_label_value(coin_module.get_conf_file_location(), "testnet") do
      {:ok, "1"} -> true
      _ -> false
    end
  end

  defp pruning_enabled?(coin_module) do
    case BoxWallet.Coins.ConfigManager.get_label_value(coin_module.get_conf_file_location(), "prune") do
      {:ok, value} ->
        case Integer.parse(value) do
          {n, _} -> n > 0
          _ -> false
        end
      _ -> false
    end
  end

  defp get_prune_size(coin_module) do
    case BoxWallet.Coins.ConfigManager.get_label_value(coin_module.get_conf_file_location(), "prune") do
      {:ok, value} ->
        case Integer.parse(value) do
          {n, _} when n >= 600 -> n
          _ -> 600
        end
      _ -> 600
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
          color: "text-pivxpurple",
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
            assigns.coin_daemon_starting -> "Daemon loading..."
            assigns.coin_daemon_started -> "Daemon running"
            assigns.coin_daemon_stopped -> "Daemon stopped"
            true -> "Idle"
          end

        %{name: "hero-face-smile", hint: hint, color: "text-pivxpurple", state: state}

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
          color: "text-pivxpurple",
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
          color: "text-pivxpurple",
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
          color: "text-pivxpurple",
          state: state
        }

      :staking ->
        %{name: "hero-bolt", hint: "Staking", color: "text-pivxpurple", state: :disabled}
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
            :unlock_for_send -> "Enter your wallet password to send:"
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
          <span>Downloading and installing PIVX... Please wait.</span>
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

    <!-- Fetching params in progress alert -->
      <%= if @fetching_params do %>
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
          <span>Downloading and installing PIVX sapling parameters... Please wait.</span>
        </div>
      <% end %>

    <!-- Fetching params success alert -->
      <%= if @fetching_params_complete do %>
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
          <span>Sapling parameters installed successfully!</span>
        </div>
      <% end %>

    <!-- Fetching params error alert -->
      <%= if @fetching_params_error do %>
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
          <span>{@fetching_params_error}</span>
        </div>
      <% end %>

      <div class="flex justify-center items-start gap-4">
        <.coin_sidebar color="text-pivxpurple" active_tab={@active_tab} />
        <div class="card bg-base-200 w-full max-w-6xl shadow-xl shadow-pivxpurple/30 p-8">
          <!-- Logo and title section -->
          <div class="flex flex-col md:flex-row items-start gap-6 mb-6">
            <img
              src={~p"/images/pivx_logo.png"}
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
                    color="text-pivxpurple"
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
                verification_progress={@verification_progress}
                color="text-pivxpurple"
                coin_files_exist={@coin_files_exist}
                downloading={@downloading}
                download_complete={@download_complete}
                download_error={@download_error}
                coin_daemon_started={@coin_daemon_started}
                coin_daemon_stopped={@coin_daemon_stopped}
                wallet_encryption_status={@wallet_encryption_status}
                on_download="download_coin"
                disk_used_bytes={@disk_used_bytes}
                disk_total_bytes={@disk_total_bytes}
              />
            <% :settings -> %>
              <.coin_settings
                coin_name={@coin_name}
                color="text-pivxpurple"
                testnet_enabled={@testnet_enabled}
                coin_files_exist={@coin_files_exist}
                downloading={@downloading}
                download_complete={@download_complete}
                download_error={@download_error}
                on_update="download_coin"
                pruning_enabled={@pruning_enabled}
                prune_size={@prune_size}
                on_prune_toggle="confirm_toggle_pruning"
              />
            <% :transactions -> %>
              <.coin_transactions color="text-pivxpurple" coin_daemon_started={@coin_daemon_started} transactions={@transactions} />
            <% :receive -> %>
              <.coin_receive color="text-pivxpurple" coin_daemon_started={@coin_daemon_started} receive_address={@receive_address} />
            <% :send -> %>
              <.coin_send color="text-pivxpurple" coin_daemon_started={@coin_daemon_started} coin_name_abbrev={@coin_name_abbrev} address_valid={@address_valid} send_address={@send_address} />
            <% _ -> %>
              <.coin_transactions color="text-pivxpurple" coin_daemon_started={@coin_daemon_started} transactions={@transactions} />
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
