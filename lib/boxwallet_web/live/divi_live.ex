defmodule BoxwalletWeb.DiviLive do
  import BoxwalletWeb.CoreWalletToolbar
  import BoxwalletWeb.CoreWalletBalance
  import BoxwalletWeb.PromptModal
  import BoxwalletWeb.WalletBalanceDisplay
  import BoxwalletWeb.SyncProgress
  import BoxwalletWeb.CoinSidebar
  import BoxwalletWeb.CoinHomeSection
  import BoxwalletWeb.CoinTransactions
  import BoxwalletWeb.CoinReceive
  import BoxwalletWeb.CoinSend
  import BoxwalletWeb.CoinSettings
  use Number
  use BoxwalletWeb, :live_view
  require Logger
  alias Boxwallet.Coins.Divi

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Boxwallet.PubSub, "divi:status")
      Divi.Server.resume_polling()
    end

    # Seed initial state from GenServer
    server_state = Divi.Server.get_state()

    socket =
      assign(socket,
        blockchain_is_synced: server_state.blockchain_is_synced,
        coin_name: "Divi",
        coin_name_abbrev: Divi.coin_name_abbrev(),
        coin_title: "The foundation for a truly decentralized future.",
        coin_description:
          "Our rapidly changing world requires flexible financial products. Through our innovative technology, we're building the future of finance.",
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
        version: server_state.version,
        coin_auth: server_state.coin_auth,
        staking_status: server_state.staking_status,
        wallet_encryption_status: server_state.wallet_encryption_status,
        hide_balance: BoxWallet.Settings.get(:hide_balance),
        show_prompt: false,
        prompt_action: nil,
        prompt_answer: "",
        prompt_confirm: "",
        passwords_match: false,
        active_tab: :home,
        transactions: server_state.transactions,
        testnet_enabled: testnet_enabled?(Divi),
        disk_used_bytes: server_state.disk_used_bytes,
        disk_total_bytes: server_state.disk_total_bytes,
        receive_address: "",
        send_address: "",
        address_valid: :empty,
        pending_send_address: nil,
        pending_send_amount: nil
      )

    {:ok, socket}
  end

  # --- PubSub handler ---

  def handle_info({:divi_state, state_map}, socket) do
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

  def handle_info(:fetch_receive_address, socket) do
    fetch_address(socket, &Divi.get_receive_address/1)
  end

  def handle_info(:new_receive_address, socket) do
    fetch_address(socket, &Divi.get_new_address/1)
  end

  defp fetch_address(socket, address_fn) do
    case socket.assigns.coin_auth do
      {:ok, auth} ->
        case address_fn.(auth) do
          {:ok, %{result: address}} when is_binary(address) ->
            {:noreply, assign(socket, :receive_address, address)}

          {:error, reason} ->
            Logger.error("Failed to get address: #{inspect(reason)}")

            {:noreply,
             socket
             |> put_flash(:error, "Failed to get a receive address.")
             |> then(fn s ->
               Process.send_after(self(), :clear_flash, 4_000)
               s
             end)}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Daemon not available.")}
    end
  end

  # --- UI Event Handlers ---

  def handle_event("toggle_hide_balance", _params, socket) do
    new_value = !socket.assigns.hide_balance
    BoxWallet.Settings.set(:hide_balance, new_value)
    {:noreply, assign(socket, :hide_balance, new_value)}
  end

  def handle_event("validate_send_address", %{"address" => address}, socket) do
    validity =
      cond do
        address == "" -> :empty
        Divi.validate_address(address) -> :valid
        true -> :invalid
      end

    {:noreply, assign(socket, send_address: address, address_valid: validity)}
  end

  def handle_event("send_coin", %{"address" => address, "amount" => amount_str}, socket) do
    wes = socket.assigns.wallet_encryption_status

    if wes in [:wes_locked, :wes_unlocked_for_staking] do
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

  defp do_send(socket, address, amount_str) do
    Process.send_after(self(), :clear_flash, 4_000)

    with true <- Divi.validate_address(address),
         {amount, _} <- Float.parse(amount_str),
         {:ok, coin_auth} <- socket.assigns.coin_auth,
         {:ok, txid} <- Divi.send_to_address(coin_auth, address, amount) do
      {:noreply,
       socket
       |> put_flash(:info, "Sent #{amount_str} #{socket.assigns.coin_name_abbrev} successfully. TX: #{txid}")
       |> assign(send_address: "", address_valid: :empty)}
    else
      false ->
        {:noreply, put_flash(socket, :error, "Invalid address.")}

      :error ->
        {:noreply, put_flash(socket, :error, "Invalid amount.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Send failed: #{reason}")}
    end
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    tab = String.to_existing_atom(tab)
    Divi.Server.set_active_tab(tab)
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

  def handle_event("new_receive_address", _params, socket) do
    send(self(), :new_receive_address)
    {:noreply, socket}
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
    # TODO: Divi.lock_wallet(coin_auth)
    {:noreply, socket}
  end

  def handle_event("prompt_submitted", %{"answer" => password}, socket) do
    Process.send_after(self(), :clear_flash, 4000)

    {:ok, coin_auth} = socket.assigns.coin_auth

    socket =
      case socket.assigns.prompt_action do
        :encrypt ->
          case Divi.wallet_encrypt(coin_auth, password) do
            :ok ->
              socket
              |> put_flash(:info, "Wallet encrypted successfully.")
              |> assign(wallet_encryption_status: :wes_locked)

            {:error, reason} ->
              put_flash(socket, :error, "Encryption failed: #{reason}")
          end

        :unlock ->
          case Divi.wallet_unlock(coin_auth, password) do
            :ok ->
              socket
              |> put_flash(:info, "Wallet unlocked successfully.")
              |> assign(wallet_encryption_status: :wes_unlocked)

            {:error, reason} ->
              put_flash(socket, :error, "Unable to unlock wallet: #{reason}")
          end

        :unlock_for_staking ->
          case Divi.wallet_unlock_fs(coin_auth, password) do
            :ok ->
              socket
              |> put_flash(:info, "Wallet unlocked for staking successfully.")
              |> assign(wallet_encryption_status: :wes_unlocked_for_staking)

            {:error, reason} ->
              put_flash(socket, :error, "Unable to unlock wallet: #{reason}")
          end

        :unlock_for_send ->
          case Divi.wallet_unlock(coin_auth, password) do
            :ok ->
              address = socket.assigns.pending_send_address
              amount_str = socket.assigns.pending_send_amount
              socket = assign(socket, wallet_encryption_status: :wes_unlocked, pending_send_address: nil, pending_send_amount: nil)
              {:noreply, send_socket} = do_send(socket, address, amount_str)
              send_socket

            {:error, reason} ->
              put_flash(socket, :error, "Unable to unlock wallet: #{reason}")
          end
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
    Divi.Server.download_coin()
    {:noreply, assign(socket, downloading: true, show_install_alert: true)}
  end

  def handle_event("start_coin_daemon", _, socket) do
    IO.puts("Attempting to start #{socket.assigns.coin_name} Daemon...")
    Divi.Server.start_daemon()
    {:noreply, assign(socket, coin_daemon_starting: true, coin_daemon_stopped: false)}
  end

  def handle_event("stop_coin_daemon", _, socket) do
    IO.puts("Attempting to stop #{socket.assigns.coin_name} Daemon...")
    Divi.Server.stop_daemon()

    Process.send_after(self(), :clear_flash, 4_000)

    {:noreply,
     socket
     |> put_flash(:info, "Stopping #{socket.assigns.coin_name} Daemon...")
     |> assign(:coin_daemon_stopping, true)
     |> assign(wallet_encryption_status: :wes_unknown)}
  end

  def handle_event("confirm_toggle_testnet", _params, socket) do
    new_value = !socket.assigns.testnet_enabled
    conf_file = Divi.get_conf_file_location()

    if new_value do
      BoxWallet.Coins.ConfigManager.enable_testnet(conf_file)
    else
      BoxWallet.Coins.ConfigManager.disable_testnet(conf_file)
    end

    Process.send_after(self(), :clear_flash, 4_000)

    if socket.assigns.coin_daemon_started do
      Divi.Server.stop_daemon()

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
          color: "text-divired",
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

        %{name: "hero-face-smile", hint: hint, color: "text-divired", state: state}

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
          color: "text-divired",
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
          color: "text-divired",
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
          color: "text-divired",
          state: state
        }

      :staking ->
        hint =
          cond do
            assigns.staking_status == "Staking Not Active" ->
              "Staking not active"

            assigns.staking_status == "Staking Active" ->
              "Staking Active :)"
          end

        state =
          cond do
            assigns.staking_status == "Staking Active" ->
              :pulsing

            assigns.staking_status == "Staking Not Active" ->
              :disabled
          end

        %{name: "hero-bolt", hint: hint, color: "text-divired", state: state}
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

      <.prompt_modal
        id="wallet-password"
        question={
          case @prompt_action do
            :encrypt -> "Enter a new password to encrypt your wallet:"
            :unlock -> "Enter your wallet password to unlock:"
            :unlock_for_staking -> "Enter your wallet password to unlock for staking:"
            :unlock_for_send -> "Enter your wallet password to unlock and send:"
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
        <.coin_sidebar color="text-divired" active_tab={@active_tab} />
        <div class="card bg-base-200 w-full max-w-6xl shadow-xl shadow-divired/30 p-8">
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

                  <.balance_display
                    balance={@balance}
                    unconfirmed_balance={@unconfirmed_balance}
                    immature_balance={@immature_balance}
                    hide_balance={@hide_balance}
                    color="text-divired"
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
                color="text-divired"
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
                color="text-divired"
                testnet_enabled={@testnet_enabled}
                coin_files_exist={@coin_files_exist}
                downloading={@downloading}
                download_complete={@download_complete}
                download_error={@download_error}
                on_update="download_coin"
              />
            <% :transactions -> %>
              <.coin_transactions color="text-divired" coin_daemon_started={@coin_daemon_started} transactions={@transactions} />
            <% :receive -> %>
              <.coin_receive color="text-divired" coin_daemon_started={@coin_daemon_started} receive_address={@receive_address} />
            <% :send -> %>
              <.coin_send color="text-divired" coin_daemon_started={@coin_daemon_started} address_valid={@address_valid} send_address={@send_address} coin_name_abbrev={@coin_name_abbrev} />
            <% _ -> %>
              <.coin_transactions color="text-divired" coin_daemon_started={@coin_daemon_started} transactions={@transactions} />
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
