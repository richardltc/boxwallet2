defmodule BoxwalletWeb.ZanoLive do
  import BoxwalletWeb.CoreWalletToolbar
  import BoxwalletWeb.CoreWalletBalance
  import BoxwalletWeb.WalletBalanceDisplay
  import BoxwalletWeb.PromptModal
  import BoxwalletWeb.SyncProgress
  import BoxwalletWeb.CoinSidebar
  import BoxwalletWeb.CoinHomeSection
  import BoxwalletWeb.CoinTransactions
  import BoxwalletWeb.ReceiveAddressModal
  use Number
  use BoxwalletWeb, :live_view
  require Logger
  alias Boxwallet.Coins.Zano

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        blockchain_is_synced: false,
        coin_name: "Zano",
        coin_title:
          "Zano (ZANO) — a privacy-focused cryptocurrency with confidential transactions and assets.",
        coin_description:
          "Zano is a scalable, secure, and privacy-centric cryptocurrency built for confidential transactions. It features hybrid PoW/PoS consensus, confidential assets, and an Ionic Swap protocol for trustless atomic swaps. Designed with a developer-friendly layer for building confidential decentralised applications.",
        show_install_alert: false,
        coin_files_exist: Zano.files_exist(),
        download_complete: false,
        download_error: nil,
        downloading: false,
        coin_daemon_starting: false,
        coin_daemon_started: false,
        coin_daemon_stopping: false,
        coin_daemon_stopped: true,
        balance: 0,
        unconfirmed_balance: 0,
        immature_balance: 0,
        block_height: 0,
        blocks_synced: 0,
        headers_synced: 0,
        blocks: 0,
        connections: 0,
        difficulty: 0,
        headers: 0,
        version: Zano.core_version(),
        coin_auth: {:error, :not_available},
        staking: false,
        wallet_encryption_status: :wes_unknown,
        hide_balance: BoxWallet.Settings.get(:hide_balance),
        show_prompt: false,
        prompt_action: nil,
        prompt_answer: "",
        prompt_confirm: "",
        passwords_match: false,
        active_tab: :home,
        transactions: [],
        show_receive_modal: false,
        receive_address: ""
      )

    {:ok, socket}
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  def handle_info({:download_complete}, socket) do
    {:noreply,
     assign(socket,
       downloading: false,
       download_complete: true,
       coin_files_exist: true
     )}
  end

  def handle_info({:download_error, reason}, socket) do
    {:noreply,
     assign(socket,
       downloading: false,
       download_error: reason
     )}
  end

  # --- UI Event Handlers ---

  def handle_event("toggle_hide_balance", _params, socket) do
    new_value = !socket.assigns.hide_balance
    BoxWallet.Settings.set(:hide_balance, new_value)
    {:noreply, assign(socket, :hide_balance, new_value)}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    tab = String.to_existing_atom(tab)
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("download_coin", _, socket) do
    parent = self()

    Task.start(fn ->
      case Zano.download_coin() do
        {:ok} -> send(parent, {:download_complete})
        {:error, reason} -> send(parent, {:download_error, reason})
      end
    end)

    {:noreply, assign(socket, downloading: true, show_install_alert: true)}
  end

  # Stub handlers for buttons rendered by coin_home_section (not wired up for Zano yet)
  def handle_event("start_coin_daemon", _, socket), do: {:noreply, socket}
  def handle_event("stop_coin_daemon", _, socket), do: {:noreply, socket}
  def handle_event("show_encrypt_prompt", _params, socket), do: {:noreply, socket}
  def handle_event("show_unlock_prompt", _params, socket), do: {:noreply, socket}
  def handle_event("show_unlock_staking_prompt", _params, socket), do: {:noreply, socket}
  def handle_event("lock_wallet", _params, socket), do: {:noreply, socket}
  def handle_event("validate_passwords", _params, socket), do: {:noreply, socket}
  def handle_event("prompt_submitted", _params, socket), do: {:noreply, socket}
  def handle_event("prompt_cancelled", _params, socket), do: {:noreply, socket}
  def handle_event("receive_address", _params, socket), do: {:noreply, socket}
  def handle_event("close_receive_modal", _params, socket), do: {:noreply, socket}

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
          color: "text-zanoblue",
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

        %{name: "hero-face-smile", hint: hint, color: "text-zanoblue", state: state}

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
              if assigns.coin_daemon_started, do: :pulsing, else: :disabled

            _ when connections > 0 ->
              :enabled

            _ ->
              :disabled
          end

        %{name: "hero-signal", hint: hint, color: "text-zanoblue", state: state}

      :syncing ->
        connections = assigns.connections

        hint =
          case connections do
            0 ->
              if !assigns.coin_daemon_stopped, do: "Waiting for connections...", else: "Idle"

            _ when connections > 0 ->
              "Syncing..."

            _ ->
              "Idle."
          end

        state =
          cond do
            assigns.coin_daemon_starting -> :disabled
            assigns.coin_daemon_started ->
              if connections > 0 and !assigns.blockchain_is_synced, do: :rotating, else: :enabled
            assigns.coin_daemon_stopped -> :disabled
            true -> :disabled
          end

        %{name: "hero-arrow-path", hint: hint, color: "text-zanoblue", state: state}

      :encryption ->
        hint =
          cond do
            assigns.wallet_encryption_status == :wes_unencrypted -> "Wallet unencrypted! Please encrypt NOW!"
            assigns.wallet_encryption_status == :wes_unlocked -> "Wallet unlocked!"
            assigns.wallet_encryption_status == :wes_locked -> "Wallet locked"
            assigns.wallet_encryption_status == :wes_unlocked_for_staking -> "Wallet unlocked for staking :)"
            assigns.wallet_encryption_status == :wes_unknown -> "Wallet encryption unknown."
          end

        state =
          cond do
            assigns.wallet_encryption_status == :wes_unencrypted -> :pulsing
            assigns.wallet_encryption_status == :wes_unlocked -> :enabled
            assigns.wallet_encryption_status == :wes_locked -> :enabled
            assigns.wallet_encryption_status == :wes_unlocked_for_staking -> :enabled
            assigns.wallet_encryption_status == :wes_unknown -> :disabled
          end

        icon_name =
          if assigns.wallet_encryption_status == :wes_locked,
            do: "hero-lock-closed",
            else: "hero-lock-open"

        %{name: icon_name, hint: hint, color: "text-zanoblue", state: state}

      :staking ->
        hint = if assigns.staking, do: "Staking Active :)", else: "Staking not active"
        state = if assigns.staking, do: :pulsing, else: :disabled
        %{name: "hero-bolt", hint: hint, color: "text-zanoblue", state: state}
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
        color="text-zanoblue"
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
          <span>Downloading and installing Zano... Please wait.</span>
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
        <.coin_sidebar color="text-zanoblue" active_tab={@active_tab} />
        <div class="card bg-base-200 w-full max-w-6xl shadow-xl shadow-zanoblue/30 p-8">
          <!-- Logo and title section -->
          <div class="flex flex-col md:flex-row items-start gap-6 mb-6">
            <img
              src={~p"/images/zano_logo.png"}
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
                    color="text-zanoblue"
                  />
                </h2>
                <p class="text-lg mt-2 mb-4">{@coin_title}</p>

                <.hero_icons_row icons={@icons} />
              </div>
            </div>
          </div>

          <%= if @active_tab == :home do %>
            <.coin_home_section
              coin_name={@coin_name}
              coin_description={@coin_description}
              headers_synced={@headers_synced}
              blocks_synced={@blocks_synced}
              block_height={@block_height}
              color="text-zanoblue"
              coin_files_exist={@coin_files_exist}
              downloading={@downloading}
              download_complete={@download_complete}
              download_error={@download_error}
              coin_daemon_started={@coin_daemon_started}
              coin_daemon_stopped={@coin_daemon_stopped}
              wallet_encryption_status={@wallet_encryption_status}
              on_download="download_coin"
            />
          <% else %>
            <.coin_transactions color="text-zanoblue" coin_daemon_started={@coin_daemon_started} transactions={@transactions} />
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
