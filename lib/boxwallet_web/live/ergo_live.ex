defmodule BoxwalletWeb.ErgoLive do
  import BoxwalletWeb.CoreWalletToolbar
  import BoxwalletWeb.WalletBalanceDisplay
  import BoxwalletWeb.PromptModal
  import BoxwalletWeb.SeedPhraseModal
  import BoxwalletWeb.CoinSidebar
  import BoxwalletWeb.CoinHomeSection
  import BoxwalletWeb.CoinTransactions
  import BoxwalletWeb.CoinReceive
  import BoxwalletWeb.CoinSend
  import BoxwalletWeb.CoinSettings

  use Number
  use BoxwalletWeb, :live_view
  require Logger
  alias Boxwallet.Coins.Ergo

  @color "text-ergoorange"

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Boxwallet.PubSub, "ergo:status")
      Ergo.Server.resume_polling()
    end

    server_state = Ergo.Server.get_state()

    socket =
      assign(socket,
        color_class: @color,
        blockchain_is_synced: server_state.blockchain_is_synced,
        coin_name: "Ergo",
        coin_name_abbrev: Ergo.coin_name_abbrev(),
        coin_title: "Ergo (ERG) — a Proof-of-Work blockchain for contractual money.",
        coin_description:
          "Launched in 2019, Ergo is a Proof-of-Work blockchain (Autolykos2) focused on financial contracts and self-sovereign applications. Its extended UTXO model and ErgoScript enable powerful, secure smart contracts while keeping mining accessible. Ergo emphasises long-term sustainability, decentralisation, and economic freedom.",
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
        version: Ergo.core_version(),
        coin_auth: server_state.coin_auth,
        wallet_encryption_status: server_state.wallet_encryption_status,
        hide_balance: BoxWallet.Settings.get(:hide_balance),
        show_prompt: false,
        prompt_action: nil,
        prompt_answer: "",
        active_tab: :home,
        transactions: server_state.transactions,
        receive_address: "",
        disk_used_bytes: server_state.disk_used_bytes,
        disk_total_bytes: server_state.disk_total_bytes,
        send_address: "",
        address_valid: :empty,
        pending_send_address: nil,
        pending_send_amount: nil,
        # Seed-phrase create/restore modal
        show_wallet_setup: false,
        wallet_setup_mode: :menu,
        wallet_setup_error: nil,
        generated_mnemonic: nil
      )

    {:ok, socket}
  end

  # --- PubSub handler ---

  def handle_info({:ergo_state, state_map}, socket) do
    was_stopping = socket.assigns.coin_daemon_stopping
    socket = assign(socket, state_map)

    socket =
      if state_map[:coin_daemon_stopped] && was_stopping do
        Process.send_after(self(), :clear_flash, 4_000)
        put_flash(socket, :info, "#{socket.assigns.coin_name} node stopped successfully.")
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(:clear_flash, socket), do: {:noreply, clear_flash(socket)}

  def handle_info(:fetch_receive_address, socket) do
    fetch_address(socket, &Ergo.get_receive_address/1)
  end

  def handle_info(:new_receive_address, socket) do
    fetch_address(socket, &Ergo.get_new_address/1)
  end

  defp fetch_address(socket, address_fn) do
    case socket.assigns.coin_auth do
      {:ok, auth} ->
        case address_fn.(auth) do
          {:ok, %{result: address}} when is_binary(address) ->
            {:noreply, assign(socket, :receive_address, address)}

          {:error, reason} ->
            Logger.error("Failed to get address: #{inspect(reason)}")
            Process.send_after(self(), :clear_flash, 4_000)
            {:noreply, put_flash(socket, :error, "Failed to get a receive address.")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Node not available.")}
    end
  end

  # --- UI event handlers ---

  def handle_event("toggle_hide_balance", _params, socket) do
    new_value = !socket.assigns.hide_balance
    BoxWallet.Settings.set(:hide_balance, new_value)
    {:noreply, assign(socket, :hide_balance, new_value)}
  end

  def handle_event("validate_send_address", %{"address" => address}, socket) do
    validity =
      cond do
        address == "" -> :empty
        Ergo.validate_address(address) -> :valid
        true -> :invalid
      end

    {:noreply, assign(socket, send_address: address, address_valid: validity)}
  end

  def handle_event("send_coin", %{"address" => address, "amount" => amount_str}, socket) do
    if socket.assigns.wallet_encryption_status == :wes_locked do
      {:noreply,
       assign(socket,
         show_prompt: true,
         prompt_action: :unlock_for_send,
         prompt_answer: "",
         pending_send_address: address,
         pending_send_amount: amount_str
       )}
    else
      do_send(socket, address, amount_str)
    end
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    tab = String.to_existing_atom(tab)
    Ergo.Server.set_active_tab(tab)
    socket = assign(socket, :active_tab, tab)

    socket =
      if tab == :receive and socket.assigns.receive_address == "" and
           socket.assigns.coin_daemon_started do
        send(self(), :fetch_receive_address)
        socket
      else
        socket
      end

    {:noreply, socket}
  end

  # --- Wallet setup (create / restore via seed phrase) ---

  def handle_event("show_wallet_setup", _params, socket) do
    {:noreply,
     assign(socket,
       show_wallet_setup: true,
       wallet_setup_mode: :menu,
       wallet_setup_error: nil,
       generated_mnemonic: nil
     )}
  end

  def handle_event("wallet_setup_choose", %{"mode" => mode}, socket) do
    mode_atom =
      case mode do
        "create" -> :create
        "restore" -> :restore
        _ -> :menu
      end

    {:noreply, assign(socket, wallet_setup_mode: mode_atom, wallet_setup_error: nil)}
  end

  def handle_event("wallet_setup_create", %{"pass" => pass, "pass_confirm" => confirm}, socket) do
    cond do
      pass == "" ->
        {:noreply, assign(socket, wallet_setup_error: "Password cannot be empty.")}

      pass != confirm ->
        {:noreply, assign(socket, wallet_setup_error: "Passwords do not match.")}

      true ->
        with {:ok, auth} <- socket.assigns.coin_auth,
             {:ok, mnemonic} <- Ergo.wallet_init(auth, pass) do
          {:noreply,
           assign(socket,
             wallet_setup_mode: :show_mnemonic,
             generated_mnemonic: mnemonic,
             wallet_setup_error: nil
           )}
        else
          {:error, reason} ->
            {:noreply, assign(socket, wallet_setup_error: "Could not create wallet: #{reason}")}

          _ ->
            {:noreply, assign(socket, wallet_setup_error: "Node not available.")}
        end
    end
  end

  def handle_event("wallet_setup_restore", %{"mnemonic" => mnemonic, "pass" => pass}, socket) do
    trimmed = String.trim(mnemonic)

    cond do
      pass == "" ->
        {:noreply, assign(socket, wallet_setup_error: "Password cannot be empty.")}

      trimmed == "" ->
        {:noreply, assign(socket, wallet_setup_error: "Recovery phrase cannot be empty.")}

      true ->
        with {:ok, auth} <- socket.assigns.coin_auth,
             :ok <- Ergo.wallet_restore(auth, pass, trimmed) do
          Process.send_after(self(), :clear_flash, 4_000)

          {:noreply,
           socket
           |> assign(show_wallet_setup: false, wallet_setup_error: nil, generated_mnemonic: nil)
           |> put_flash(:info, "Wallet restored successfully.")}
        else
          {:error, reason} ->
            {:noreply, assign(socket, wallet_setup_error: "Could not restore wallet: #{reason}")}

          _ ->
            {:noreply, assign(socket, wallet_setup_error: "Node not available.")}
        end
    end
  end

  def handle_event("wallet_setup_mnemonic_done", _params, socket) do
    Process.send_after(self(), :clear_flash, 6_000)

    {:noreply,
     socket
     |> assign(show_wallet_setup: false, generated_mnemonic: nil, wallet_setup_error: nil)
     |> put_flash(:info, "Wallet created. Keep your recovery phrase somewhere safe!")}
  end

  def handle_event("wallet_setup_cancel", _params, socket) do
    {:noreply,
     assign(socket,
       show_wallet_setup: false,
       wallet_setup_mode: :menu,
       wallet_setup_error: nil,
       generated_mnemonic: nil
     )}
  end

  # --- Unlock / lock ---

  def handle_event("show_unlock_prompt", _params, socket) do
    {:noreply, assign(socket, show_prompt: true, prompt_action: :unlock, prompt_answer: "")}
  end

  # Ergo has no staking; map the (hidden) staking-unlock action to a normal unlock.
  def handle_event("show_unlock_staking_prompt", _params, socket) do
    {:noreply, assign(socket, show_prompt: true, prompt_action: :unlock, prompt_answer: "")}
  end

  def handle_event("lock_wallet", _params, socket) do
    case socket.assigns.coin_auth do
      {:ok, auth} ->
        case Ergo.wallet_lock(auth) do
          :ok -> {:noreply, assign(socket, wallet_encryption_status: :wes_locked)}
          {:error, reason} -> {:noreply, put_flash(socket, :error, "Could not lock: #{reason}")}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("prompt_submitted", %{"answer" => password}, socket) do
    Process.send_after(self(), :clear_flash, 4_000)
    {:ok, coin_auth} = socket.assigns.coin_auth

    socket =
      case socket.assigns.prompt_action do
        :unlock ->
          case Ergo.wallet_unlock(coin_auth, password) do
            :ok ->
              socket
              |> put_flash(:info, "Wallet unlocked successfully.")
              |> assign(wallet_encryption_status: :wes_unlocked)

            {:error, reason} ->
              put_flash(socket, :error, "Unable to unlock wallet: #{reason}")
          end

        :unlock_for_send ->
          case Ergo.wallet_unlock(coin_auth, password) do
            :ok ->
              address = socket.assigns.pending_send_address
              amount_str = socket.assigns.pending_send_amount

              socket =
                assign(socket,
                  wallet_encryption_status: :wes_unlocked,
                  pending_send_address: nil,
                  pending_send_amount: nil
                )

              {:noreply, send_socket} = do_send(socket, address, amount_str)
              send_socket

            {:error, reason} ->
              put_flash(socket, :error, "Unable to unlock wallet: #{reason}")
          end

        _ ->
          socket
      end

    {:noreply, assign(socket, show_prompt: false, prompt_action: nil)}
  end

  def handle_event("new_receive_address", _params, socket) do
    send(self(), :new_receive_address)
    {:noreply, socket}
  end

  def handle_event("prompt_cancelled", _params, socket) do
    {:noreply, assign(socket, show_prompt: false, prompt_action: nil, prompt_answer: "")}
  end

  def handle_event("download_coin", _, socket) do
    Ergo.Server.download_coin()
    {:noreply, assign(socket, downloading: true, show_install_alert: true)}
  end

  def handle_event("start_coin_daemon", _, socket) do
    Ergo.Server.start_daemon()
    {:noreply, assign(socket, coin_daemon_starting: true, coin_daemon_stopped: false)}
  end

  def handle_event("stop_coin_daemon", _, socket) do
    Ergo.Server.stop_daemon()
    Process.send_after(self(), :clear_flash, 4_000)

    {:noreply,
     socket
     |> put_flash(:info, "Stopping #{socket.assigns.coin_name} node...")
     |> assign(:coin_daemon_stopping, true)
     |> assign(wallet_encryption_status: :wes_unknown)}
  end

  defp do_send(socket, address, amount_str) do
    Process.send_after(self(), :clear_flash, 4_000)

    with true <- Ergo.validate_address(address),
         {amount, _} <- Float.parse(amount_str),
         {:ok, coin_auth} <- socket.assigns.coin_auth,
         {:ok, txid} <- Ergo.send_to_address(coin_auth, address, amount) do
      {:noreply,
       socket
       |> put_flash(
         :info,
         "Sent #{amount_str} #{socket.assigns.coin_name_abbrev} successfully. TX: #{txid}"
       )
       |> assign(send_address: "", address_valid: :empty)}
    else
      false -> {:noreply, put_flash(socket, :error, "Invalid address.")}
      :error -> {:noreply, put_flash(socket, :error, "Invalid amount.")}
      {:error, reason} -> {:noreply, put_flash(socket, :error, "Send failed: #{reason}")}
    end
  end

  # --- Toolbar icons ---

  defp get_icon_state(name, assigns) do
    case name do
      :files ->
        %{
          name: "hero-arrow-down-tray",
          hint: if(assigns.coin_files_exist, do: "Core files exist", else: "Core files not downloaded"),
          color: @color,
          state: if(assigns.coin_files_exist, do: :enabled, else: :disabled)
        }

      :daemon ->
        state =
          cond do
            assigns.coin_daemon_starting -> :pulsing
            assigns.coin_daemon_started -> :enabled
            true -> :disabled
          end

        hint =
          cond do
            assigns.coin_daemon_starting -> "Node starting..."
            assigns.coin_daemon_started -> "Node running"
            assigns.coin_daemon_stopped -> "Node stopped"
            true -> "Idle"
          end

        %{name: "hero-face-smile", hint: hint, color: @color, state: state}

      :connections ->
        connections = assigns.connections

        hint =
          cond do
            connections > 0 -> "#{connections} connections"
            !assigns.coin_daemon_stopped -> "Searching for connections..."
            true -> "Idle"
          end

        state =
          cond do
            connections > 0 -> :enabled
            assigns.coin_daemon_started -> :pulsing
            true -> :disabled
          end

        %{name: "hero-signal", hint: hint, color: @color, state: state}

      :syncing ->
        state =
          cond do
            assigns.coin_daemon_starting -> :disabled
            assigns.coin_daemon_started ->
              if assigns.connections > 0 and !assigns.blockchain_is_synced,
                do: :rotating,
                else: :enabled

            true -> :disabled
          end

        hint =
          cond do
            assigns.connections > 0 and !assigns.blockchain_is_synced -> "Syncing..."
            assigns.coin_daemon_started -> "Synced"
            !assigns.coin_daemon_stopped -> "Waiting for connections..."
            true -> "Idle"
          end

        %{name: "hero-arrow-path", hint: hint, color: @color, state: state}

      :encryption ->
        hint =
          case assigns.wallet_encryption_status do
            :wes_unencrypted -> "No wallet yet — create or restore one."
            :wes_unlocked -> "Wallet unlocked!"
            :wes_locked -> "Wallet locked"
            _ -> "Wallet status unknown."
          end

        state =
          case assigns.wallet_encryption_status do
            :wes_unencrypted -> :pulsing
            :wes_unlocked -> :enabled
            :wes_locked -> :enabled
            _ -> :disabled
          end

        name =
          if assigns.wallet_encryption_status == :wes_locked,
            do: "hero-lock-closed",
            else: "hero-lock-open"

        %{name: name, hint: hint, color: @color, state: state}

      :mining ->
        %{
          name: "hero-cpu-chip",
          hint: "Mining not supported",
          color: @color,
          state: :disabled
        }
    end
  end

  def render(assigns) do
    icon_list = [
      get_icon_state(:files, assigns),
      get_icon_state(:daemon, assigns),
      get_icon_state(:connections, assigns),
      get_icon_state(:syncing, assigns),
      get_icon_state(:encryption, assigns),
      get_icon_state(:mining, assigns)
    ]

    assigns = assign(assigns, :icons, icon_list)

    ~H"""
    <Layouts.app flash={@flash}>
      <.wallet_setup_modal
        id="ergo-wallet-setup"
        show={@show_wallet_setup}
        mode={@wallet_setup_mode}
        mnemonic={@generated_mnemonic}
        error={@wallet_setup_error}
        color={@color_class}
        on_choose="wallet_setup_choose"
        on_create="wallet_setup_create"
        on_restore="wallet_setup_restore"
        on_mnemonic_done="wallet_setup_mnemonic_done"
        on_cancel="wallet_setup_cancel"
      />

      <.prompt_modal
        id="wallet-password"
        question={
          case @prompt_action do
            :unlock -> "Enter your wallet password to unlock:"
            :unlock_for_send -> "Enter your wallet password to send:"
            _ -> "Enter your wallet password:"
          end
        }
        icon="hero-lock-closed"
        show={@show_prompt}
        on_confirm="prompt_submitted"
        on_cancel="prompt_cancelled"
        answer_value={@prompt_answer}
        input_type="password"
        placeholder="Enter password..."
      />

      <div :if={@downloading} role="alert" class="alert alert-info mb-4">
        <span class="loading loading-spinner loading-sm"></span>
        <span>Downloading the Ergo node... Please wait.</span>
      </div>

      <div :if={@download_complete} role="alert" class="alert alert-success mb-4">
        <.icon name="hero-check-circle" class="h-6 w-6 shrink-0" />
        <span>Download completed successfully!</span>
      </div>

      <div :if={@download_error} role="alert" class="alert alert-error mb-4">
        <.icon name="hero-x-circle" class="h-6 w-6 shrink-0" />
        <span>{@download_error}</span>
      </div>

      <div class="flex justify-center items-start gap-4">
        <.coin_sidebar color={@color_class} active_tab={@active_tab} />
        <div class="card bg-base-200 w-full max-w-6xl shadow-xl shadow-ergoorange/30 p-8">
          <div class="flex flex-col md:flex-row items-start gap-6 mb-6">
            <img
              src="/images/erg_logo.png"
              alt="Ergo logo"
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
                    color={@color_class}
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
                color={@color_class}
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
                unencrypted_label="Create Wallet"
                on_unencrypted="show_wallet_setup"
                show_unlock_for_staking={false}
              />
            <% :settings -> %>
              <.coin_settings
                coin_name={@coin_name}
                color={@color_class}
                testnet_enabled={false}
                show_testnet={false}
                coin_files_exist={@coin_files_exist}
                downloading={@downloading}
                download_complete={@download_complete}
                download_error={@download_error}
                on_update="download_coin"
              />
            <% :transactions -> %>
              <.coin_transactions
                color={@color_class}
                coin_daemon_started={@coin_daemon_started}
                transactions={@transactions}
              />
            <% :receive -> %>
              <.coin_receive
                color={@color_class}
                coin_daemon_started={@coin_daemon_started}
                receive_address={@receive_address}
                wallet_encryption_status={@wallet_encryption_status}
              />
            <% :send -> %>
              <.coin_send
                color={@color_class}
                coin_daemon_started={@coin_daemon_started}
                address_valid={@address_valid}
                send_address={@send_address}
                coin_name_abbrev={@coin_name_abbrev}
              />
            <% _ -> %>
              <.coin_transactions
                color={@color_class}
                coin_daemon_started={@coin_daemon_started}
                transactions={@transactions}
              />
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
