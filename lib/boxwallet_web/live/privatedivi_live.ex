defmodule BoxwalletWeb.PrivateDiviLive do
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
  use Number
  use BoxwalletWeb, :live_view
  require Logger
  alias Boxwallet.Coins.PrivateDivi

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        blockchain_is_synced: false,
        coin_name: "PrivateDivi",
        coin_name_abbrev: PrivateDivi.coin_name_abbrev(),
        coin_title: "Private cryptocurrency network.",
        coin_description:
          "PrivateDivi is a private cryptocurrency network built on the Divi codebase, delivering fast and secure transactions.",
        show_install_alert: false,
        coin_files_exist: PrivateDivi.files_exist(),
        download_complete: false,
        download_error: nil,
        downloading: false,
        coin_daemon_starting: false,
        coin_daemon_started: false,
        coin_daemon_stopping: false,
        coin_daemon_stopped: true,
        balance: 0.0,
        unconfirmed_balance: 0.0,
        immature_balance: 0.0,
        block_height: 0,
        blocks_synced: 0,
        headers_synced: 0,
        connections: 0,
        difficulty: 0,
        show_prompt: false,
        staking_status: "Staking Not Active",
        version: "...",
        coin_auth: PrivateDivi.get_auth_values(),
        wallet_encryption_status: :wes_unknown,
        prompt_action: nil,
        prompt_answer: "",
        prompt_confirm: "",
        passwords_match: false,
        hide_balance: BoxWallet.Settings.get(:hide_balance),
        active_tab: :home,
        testnet_enabled: testnet_enabled?(PrivateDivi),
        disk_used_bytes: disk_used_bytes(),
        disk_total_bytes: disk_total_bytes()
      )

    if connected?(socket) do
      send(self(), :verify_daemon_status)
    end

    {:ok,
     socket
     |> assign(:coin_daemon_started, false)
     |> assign(:coin_daemon_stopped, true)
     |> assign(:checking_daemon, true)}
  end

  def handle_info(:verify_daemon_status, socket) do
    case socket.assigns.coin_auth do
      {:ok, coin_auth} ->
        case PrivateDivi.daemon_is_running(coin_auth) do
          true ->
            IO.puts("#{socket.assigns.coin_name} Verify daemon status - Daemon is alive!")

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

      {:error, :enoent} ->
        IO.puts(
          "#{socket.assigns.coin_name} Config file not found. User probably needs to install/download."
        )

        {:noreply, assign(socket, checking_daemon: false)}

      {:error, reason} ->
        IO.puts("Error loading auth: #{inspect(reason)}")
        {:noreply, assign(socket, checking_daemon: false)}
    end
  end

  def handle_info(:check_get_blockchain_info_status, socket) do
    if socket.assigns.coin_daemon_starting or socket.assigns.coin_daemon_started do
      {:ok, coin_auth} = socket.assigns.coin_auth

      case PrivateDivi.get_blockchain_info(coin_auth) do
        {:ok, response} ->
          socket =
            socket
            |> assign(:get_blockchain_info_response, response)
            |> assign(:blocks_synced, response.result.blocks || 0)
            |> assign(:difficulty,
              Number.Delimit.number_to_delimited(response.result.difficulty, precision: 0) || 0
            )
            |> assign(:headers_synced, response.result.headers || 0)

          {:noreply, socket}

        {:error, _reason} ->
          IO.puts("#{socket.assigns.coin_name} Daemon not ready yet... retrying in 2s")
          Process.send_after(self(), :check_get_blockchain_info_status, 2000)
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info(:check_get_info_status, socket) do
    if socket.assigns.coin_daemon_starting or socket.assigns.coin_daemon_started do
      {:ok, coin_auth} = socket.assigns.coin_auth

      case PrivateDivi.get_info(coin_auth) do
        {:ok, response} ->
          IO.puts("#{socket.assigns.coin_name} Daemon is alive!")

          socket =
            socket
            |> assign(:coin_daemon_starting, false)
            |> assign(:coin_daemon_started, true)
            |> assign(:getinfo_response, response)
            |> assign(:connections, response.result.connections || 0)
            |> assign(:staking_status, response.result.staking_status || "Staking Not Active")
            |> assign(:version, response.result.version || "v...")

          Process.send_after(self(), :check_get_info_status, 2000)
          Process.send_after(self(), :check_get_blockchain_info_status, 2000)
          Process.send_after(self(), :check_get_wallet_info_status, 2000)
          Process.send_after(self(), :check_get_mn_sync_status, 2000)
          {:noreply, socket}

        {:error, _reason} ->
          IO.puts("#{socket.assigns.coin_name} Daemon not ready yet... retrying in 2s")
          Process.send_after(self(), :check_get_info_status, 2000)
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info(:check_get_mn_sync_status, socket) do
    if socket.assigns.coin_daemon_starting or socket.assigns.coin_daemon_started do
      {:ok, coin_auth} = socket.assigns.coin_auth

      case PrivateDivi.get_mn_sync_status(coin_auth) do
        {:ok, response} ->
          blockchain_is_synced = response.result.is_blockchain_synced

          socket =
            socket
            |> assign(:blockchain_is_synced, blockchain_is_synced)

          {:noreply, socket}

        {:error, _reason} ->
          IO.puts("Unable to get_mn_sync_status... retrying in 2s")
          Process.send_after(self(), :check_get_mn_sync_status, 2000)
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info(:check_get_wallet_info_status, socket) do
    if socket.assigns.coin_daemon_starting or socket.assigns.coin_daemon_started do
      {:ok, coin_auth} = socket.assigns.coin_auth

      case PrivateDivi.get_wallet_info(coin_auth) do
        {:ok, response} ->
          wallet_encryption_status =
            case response.result.encryption_status do
              "unencrypted" -> :wes_unencrypted
              "unlocked" -> :wes_unlocked
              "locked" -> :wes_locked
              "unlocked-for-staking" -> :wes_unlocked_for_staking
            end

          socket =
            socket
            |> assign(:wallet_encryption_status, wallet_encryption_status)
            |> assign(:balance, response.result.balance)
            |> assign(:unconfirmed_balance, response.result.unconfirmed_balance || 0.0)
            |> assign(:immature_balance, response.result.immature_balance || 0.0)

          {:noreply, socket}

        {:error, _reason} ->
          IO.puts("Unable to get_wallet_info... retrying in 2s")
          Process.send_after(self(), :check_get_wallet_info_status, 2000)
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:daemon_stop_result, {:ok, _response}}, socket) do
    Process.send_after(self(), :clear_flash, 4000)

    {:noreply,
     socket
     |> put_flash(:info, "#{socket.assigns.coin_name} Daemon stopped successfully")
     |> assign(:coin_daemon_starting, false)
     |> assign(:coin_daemon_started, false)
     |> assign(:coin_daemon_stopped, true)
     |> assign(:connections, 0)
     |> assign(:blocks_synced, 0)
     |> assign(:headers_synced, 0)
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

  def handle_info(:hide_success_message, socket) do
    socket = assign(socket, download_complete: false)
    {:noreply, socket}
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  def handle_info(:perform_download, socket) do
    IO.puts("Performing download")

    case PrivateDivi.download_coin() do
      {:ok} ->
        IO.puts("#{socket.assigns.coin_name} Download completed successfully")

        socket =
          socket
          |> assign(downloading: false)
          |> assign(show_install_alert: false)
          |> assign(download_complete: true)
          |> assign(coin_files_exist: true)
          |> assign(download_error: nil)
          |> assign(coin_auth: PrivateDivi.get_auth_values())

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

  def handle_event("download_privatedivi", _, socket) do
    IO.puts("Starting download event")
    socket = assign(socket, downloading: true, show_install_alert: true)
    send(self(), :perform_download)
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
    # TODO: PrivateDivi.lock_wallet(coin_auth)
    {:noreply, socket}
  end

  def handle_event("prompt_submitted", %{"answer" => password}, socket) do
    Process.send_after(self(), :clear_flash, 4000)

    {:ok, coin_auth} = socket.assigns.coin_auth

    socket =
      case socket.assigns.prompt_action do
        :encrypt ->
          case PrivateDivi.wallet_encrypt(coin_auth, password) do
            :ok ->
              socket
              |> put_flash(:info, "Wallet encrypted successfully.")
              |> assign(wallet_encryption_status: :wes_locked)

            {:error, reason} ->
              put_flash(socket, :error, "Encryption failed: #{reason}")
          end

        :unlock ->
          case PrivateDivi.wallet_unlock(coin_auth, password) do
            :ok ->
              socket
              |> put_flash(:info, "Wallet unlocked successfully.")
              |> assign(wallet_encryption_status: :wes_unlocked)

            {:error, reason} ->
              put_flash(socket, :error, "Unable to unlock wallet: #{reason}")
          end

        :unlock_for_staking ->
          case PrivateDivi.wallet_unlock_fs(coin_auth, password) do
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

  def handle_event("toggle_hide_balance", _params, socket) do
    new_value = !socket.assigns.hide_balance
    BoxWallet.Settings.set(:hide_balance, new_value)
    {:noreply, assign(socket, :hide_balance, new_value)}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
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

  def handle_event("start_coin_daemon", _, socket) do
    IO.puts("Attempting to start #{socket.assigns.coin_name} Daemon...")

    socket =
      case PrivateDivi.start_daemon() do
        {:ok} ->
          IO.puts("#{socket.assigns.coin_name} Starting...")

          socket =
            socket
            |> assign(:coin_daemon_starting, true)
            |> assign(:coin_daemon_started, false)
            |> assign(:coin_daemon_stopped, false)

          IO.puts("Calling getinfo...")
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
      result = PrivateDivi.stop_daemon(coin_auth)
      send(parent, {:daemon_stop_result, result})
    end)

    {:noreply,
     socket
     |> put_flash(:info, "Stopping daemon...")
     |> assign(:coin_daemon_stopping, true)
     |> assign(wallet_encryption_status: :wes_unknown)}
  end

  def handle_event("confirm_toggle_testnet", _params, socket) do
    new_value = !socket.assigns.testnet_enabled
    conf_file = PrivateDivi.get_conf_file_location()

    if new_value do
      BoxWallet.Coins.ConfigManager.enable_testnet(conf_file)
    else
      BoxWallet.Coins.ConfigManager.disable_testnet(conf_file)
    end

    Process.send_after(self(), :clear_flash, 4_000)

    if socket.assigns.coin_daemon_started do
      {:ok, coin_auth} = socket.assigns.coin_auth
      parent = self()

      spawn(fn ->
        result = PrivateDivi.stop_daemon(coin_auth)
        send(parent, {:daemon_stop_result, result})
      end)

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

  defp disk_used_bytes do
    case BoxWallet.Coins.CoinHelper.disk_free() do
      {:ok, %{total: total_mb, free: free_mb}} -> (total_mb - free_mb) * 1_048_576
      _ -> 0
    end
  end

  defp disk_total_bytes do
    case BoxWallet.Coins.CoinHelper.disk_free() do
      {:ok, %{total: total_mb}} -> total_mb * 1_048_576
      _ -> 0
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

        %{name: "hero-bolt", hint: hint, color: "text-red-400", state: state}
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
          <span>Downloading and installing PrivateDivi... Please wait.</span>
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
        <.coin_sidebar color="text-red-400" active_tab={@active_tab} />
        <div class="card bg-base-200 w-full max-w-6xl shadow-xl shadow-red-400/30 p-8">
          <!-- Logo and title section -->
          <div class="flex flex-col md:flex-row items-start gap-6 mb-6">
            <div style="width: 7.5rem; height: 7.5rem; background: linear-gradient(135deg, #E94560, #D03A52); border-radius: 1rem; display: flex; align-items: center; justify-content: center; box-shadow: 0 4px 20px rgba(233, 69, 96, 0.3);">
              <svg viewBox="0 0 24 24" fill="white" class="h-16 w-16">
                <path d="M12 2L2 7v10c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V7l-10-5zm0 18.5c-3.86-.95-6.5-4.95-6.5-8.5V8.3l6.5-3.25 6.5 3.25V12c0 3.55-2.64 7.55-6.5 8.5z" />
              </svg>
            </div>
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
                    color="text-red-400"
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
                color="text-red-400"
                coin_files_exist={@coin_files_exist}
                downloading={@downloading}
                download_complete={@download_complete}
                download_error={@download_error}
                coin_daemon_started={@coin_daemon_started}
                coin_daemon_stopped={@coin_daemon_stopped}
                wallet_encryption_status={@wallet_encryption_status}
                on_download="download_privatedivi"
                disk_used_bytes={@disk_used_bytes}
                disk_total_bytes={@disk_total_bytes}
              />
            <% :settings -> %>
              <.coin_settings
                coin_name={@coin_name}
                color="text-red-400"
                testnet_enabled={@testnet_enabled}
                coin_files_exist={@coin_files_exist}
                downloading={@downloading}
                download_complete={@download_complete}
                download_error={@download_error}
                on_update="download_privatedivi"
              />
            <% :receive -> %>
              <.coin_transactions color="text-red-400" />
            <% :send -> %>
              <.coin_send color="text-red-400" coin_daemon_started={@coin_daemon_started} coin_name_abbrev={@coin_name_abbrev} />
            <% _ -> %>
              <.coin_transactions color="text-red-400" />
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
