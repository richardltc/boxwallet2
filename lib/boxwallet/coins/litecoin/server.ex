defmodule Boxwallet.Coins.Litecoin.Server do
  use GenServer
  require Logger

  alias Boxwallet.Coins.Litecoin

  @blockchain_info_interval 3_000
  @wallet_info_interval 5_000
  @block_height_interval 60_000
  @peer_info_interval 15_000
  @transactions_interval_fast 3_000
  @transactions_interval_slow 15_000
  @disk_usage_interval 60_000

  # --- Public API ---

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def start_daemon do
    GenServer.cast(__MODULE__, :start_daemon)
  end

  def stop_daemon do
    GenServer.cast(__MODULE__, :stop_daemon)
  end

  def download_coin do
    GenServer.cast(__MODULE__, :download_coin)
  end

  def refresh do
    GenServer.cast(__MODULE__, :refresh)
  end

  def set_active_tab(tab) do
    GenServer.cast(__MODULE__, {:set_active_tab, tab})
  end

  def pause_polling do
    GenServer.cast(__MODULE__, :pause_polling)
  end

  def resume_polling do
    GenServer.cast(__MODULE__, :resume_polling)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(:ok) do
    coin_auth = Litecoin.get_auth_values()
    coin_files_exist = Litecoin.files_exist()

    {disk_used_bytes, disk_total_bytes} =
      case BoxWallet.Coins.CoinHelper.disk_free() do
        {:ok, %{total: total_mb, free: free_mb}} ->
          {(total_mb - free_mb) * 1_048_576, total_mb * 1_048_576}

        _ ->
          {0, 0}
      end

    state = %{
      coin_auth: coin_auth,
      daemon_status: :stopped,
      wallet_loaded: false,
      blocks: 0,
      headers: 0,
      blocks_synced: 0,
      headers_synced: 0,
      verification_progress: 0.0,
      daemon_warmup_status: nil,
      difficulty: 0,
      connections: 0,
      block_height: 0,
      blockchain_is_synced: false,
      balance: 0.0,
      unconfirmed_balance: 0.0,
      immature_balance: 0.0,
      wallet_encryption_status: :wes_unknown,
      coin_files_exist: coin_files_exist,
      downloading: false,
      download_complete: false,
      download_error: nil,
      transactions: [],
      active_tab: :home,
      transactions_timer: nil,
      polling_paused: false,
      disk_used_bytes: disk_used_bytes,
      disk_total_bytes: disk_total_bytes
    }

    # Check if daemon is already running
    state =
      case coin_auth do
        {:ok, auth} ->
          if Litecoin.daemon_is_running(auth) do
            Logger.info("Litecoin daemon already running on init")
            schedule_polls()
            %{state | daemon_status: :running}
          else
            state
          end

        _ ->
          state
      end

    Process.send_after(self(), :poll_disk_usage, @disk_usage_interval)

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {disk_used_bytes, disk_total_bytes} =
      case BoxWallet.Coins.CoinHelper.disk_free() do
        {:ok, %{total: total_mb, free: free_mb}} ->
          {(total_mb - free_mb) * 1_048_576, total_mb * 1_048_576}

        _ ->
          {state.disk_used_bytes, state.disk_total_bytes}
      end

    state = %{state | disk_used_bytes: disk_used_bytes, disk_total_bytes: disk_total_bytes}
    {:reply, state, state}
  end

  @impl true
  def handle_cast(:start_daemon, state) do
    case Litecoin.start_daemon() do
      {:ok} ->
        Logger.info("Litecoin daemon starting...")
        state = %{state | daemon_status: :starting, wallet_loaded: false}
        broadcast(state)
        # Start blockchain polling — wallet polling starts after wallet is loaded
        Process.send_after(self(), :poll_blockchain_info, 2_000)
        Process.send_after(self(), :poll_block_height, 5_000)
        Process.send_after(self(), :poll_peer_info, 10_000)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Failed to start Litecoin daemon: #{inspect(reason)}")
        broadcast(state)
        {:noreply, state}
    end
  end

  def handle_cast(:stop_daemon, state) do
    case state.coin_auth do
      {:ok, auth} ->
        state = %{state | daemon_status: :stopping}
        broadcast(state)

        # Stop daemon in a spawned process to avoid blocking
        server = self()

        spawn(fn ->
          result = Litecoin.stop_daemon(auth)
          send(server, {:daemon_stop_result, result})
        end)

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_cast(:download_coin, state) do
    state = %{state | downloading: true, download_complete: false, download_error: nil}
    broadcast(state)

    server = self()

    spawn(fn ->
      result = Litecoin.download_coin()
      send(server, {:download_result, result})
    end)

    {:noreply, state}
  end

  def handle_cast({:set_active_tab, tab}, state) do
    state = %{state | active_tab: tab}

    # Kick off an immediate poll when switching to transactions tab
    state =
      if tab == :transactions and state.daemon_status == :running and state.wallet_loaded do
        schedule_transactions_poll(state, 0)
      else
        state
      end

    {:noreply, state}
  end

  def handle_cast(:pause_polling, state) do
    Logger.info("Litecoin polling paused")
    {:noreply, %{state | polling_paused: true}}
  end

  def handle_cast(:resume_polling, state) do
    state = %{state | polling_paused: false}

    if state.daemon_status in [:starting, :running] do
      Logger.info("Litecoin polling resumed")
      schedule_polls()

      if state.wallet_loaded do
        maybe_reschedule(state, :poll_wallet_info, 1_000)
        state = schedule_transactions_poll(state, 3_000)
        {:noreply, state}
      else
        {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  def handle_cast(:refresh, %{daemon_status: :running} = state) do
    send(self(), :poll_blockchain_info)
    send(self(), :poll_wallet_info)
    {:noreply, state}
  end

  def handle_cast(:refresh, state), do: {:noreply, state}

  # Poll triggers — spawn the blocking RPC call so GenServer stays responsive
  @impl true
  def handle_info(:poll_blockchain_info, %{daemon_status: status, polling_paused: false} = state)
      when status in [:starting, :running] do
    case state.coin_auth do
      {:ok, auth} ->
        server = self()

        spawn(fn ->
          result = Litecoin.get_blockchain_info(auth)
          send(server, {:blockchain_info_result, result})
        end)

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(:poll_blockchain_info, state), do: {:noreply, state}

  def handle_info(:poll_wallet_info, %{daemon_status: status, polling_paused: false} = state)
      when status in [:starting, :running] do
    case state.coin_auth do
      {:ok, auth} ->
        server = self()

        spawn(fn ->
          result = Litecoin.get_wallet_info(auth)
          send(server, {:wallet_info_result, result})
        end)

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(:poll_wallet_info, state), do: {:noreply, state}

  def handle_info(:poll_peer_info, %{daemon_status: status, polling_paused: false} = state)
      when status in [:starting, :running] do
    case state.coin_auth do
      {:ok, auth} ->
        server = self()

        spawn(fn ->
          result = Litecoin.get_peer_info(auth)
          send(server, {:peer_info_result, result})
        end)

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(:poll_peer_info, state), do: {:noreply, state}

  def handle_info(:poll_transactions, %{daemon_status: status, polling_paused: false} = state)
      when status in [:starting, :running] do
    case state.coin_auth do
      {:ok, auth} ->
        server = self()

        spawn(fn ->
          result = Litecoin.list_transactions(auth)
          send(server, {:transactions_result, result})
        end)

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(:poll_transactions, state), do: {:noreply, state}

  def handle_info(:poll_block_height, %{daemon_status: status, polling_paused: false} = state)
      when status in [:starting, :running] do
    server = self()

    spawn(fn ->
      result = Litecoin.get_block_height()
      send(server, {:block_height_result, result})
    end)

    {:noreply, state}
  end

  def handle_info(:poll_block_height, state), do: {:noreply, state}

  # Results from spawned RPC calls
  def handle_info({:blockchain_info_result, {:warming_up, status}}, state) do
    state = %{state | daemon_warmup_status: status}
    broadcast(state)
    maybe_reschedule(state, :poll_blockchain_info, 1_000)
    {:noreply, state}
  end

  def handle_info({:blockchain_info_result, {:ok, response}}, state) do
    # If wallet hasn't been loaded yet, trigger load now that daemon is confirmed up
    unless state.wallet_loaded do
      send(self(), :load_wallet)
    end

    state = %{
      state
      | daemon_status: if(state.daemon_status in [:starting, :running], do: :running, else: state.daemon_status),
        daemon_warmup_status: nil,
        blocks_synced: response.result.blocks || 0,
        blocks:
          Number.Delimit.number_to_delimited(response.result.blocks, precision: 0) || 0,
        difficulty:
          Number.Delimit.number_to_delimited(response.result.difficulty, precision: 0) || 0,
        headers_synced: response.result.headers || 0,
        headers:
          Number.Delimit.number_to_delimited(response.result.headers, precision: 0) || 0,
        verification_progress: response.result.verificationprogress || 0.0,
        blockchain_is_synced:
          (response.result.verificationprogress || 0) >= 0.9999
    }

    broadcast(state)
    maybe_reschedule(state, :poll_blockchain_info, @blockchain_info_interval)
    {:noreply, state}
  end

  def handle_info({:blockchain_info_result, {:error, _reason}}, state) do
    Logger.warning("Litecoin blockchain info poll failed, retrying...")
    maybe_reschedule(state, :poll_blockchain_info, 2_000)
    {:noreply, state}
  end

  def handle_info({:wallet_info_result, {:ok, response}}, state) do
    wallet_encryption_status =
      case response.result.unlocked_until do
        nil -> :wes_unencrypted
        0 -> :wes_locked
        _ -> :wes_unlocked
      end

    state = %{
      state
      | daemon_status: if(state.daemon_status in [:starting, :running], do: :running, else: state.daemon_status),
        wallet_encryption_status: wallet_encryption_status,
        balance: response.result.balance,
        unconfirmed_balance: response.result.unconfirmed_balance || 0.0,
        immature_balance: response.result.immature_balance || 0.0
    }

    broadcast(state)
    maybe_reschedule(state, :poll_wallet_info, @wallet_info_interval)
    {:noreply, state}
  end

  def handle_info({:wallet_info_result, {:error, _reason}}, state) do
    Logger.warning("Litecoin wallet info poll failed, retrying...")
    maybe_reschedule(state, :poll_wallet_info, 2_000)
    {:noreply, state}
  end

  def handle_info({:block_height_result, {:ok, count}}, state) do
    state = %{state | block_height: count}
    broadcast(state)
    maybe_reschedule(state, :poll_block_height, @block_height_interval)
    {:noreply, state}
  end

  def handle_info({:block_height_result, {:error, reason}}, state) do
    Logger.warning("Unable to get block height: #{inspect(reason)}, retrying in 65s")
    maybe_reschedule(state, :poll_block_height, 65_000)
    {:noreply, state}
  end

  def handle_info({:peer_info_result, {:ok, response}}, state) do
    connections = length(response.result)
    state = %{state | connections: connections}
    broadcast(state)
    maybe_reschedule(state, :poll_peer_info, @peer_info_interval)
    {:noreply, state}
  end

  def handle_info({:peer_info_result, {:error, reason}}, state) do
    Logger.warning("Litecoin peer info poll failed: #{inspect(reason)}, retrying...")
    maybe_reschedule(state, :poll_peer_info, @peer_info_interval)
    {:noreply, state}
  end

  def handle_info({:transactions_result, {:ok, response}}, state) do
    state = %{state | transactions: response.result}
    broadcast(state)

    interval =
      if state.active_tab == :transactions,
        do: @transactions_interval_fast,
        else: @transactions_interval_slow

    state = schedule_transactions_poll(state, interval)
    {:noreply, state}
  end

  def handle_info({:transactions_result, {:error, reason}}, state) do
    Logger.warning("Litecoin transactions poll failed: #{inspect(reason)}, retrying...")
    state = schedule_transactions_poll(state, @transactions_interval_slow)
    {:noreply, state}
  end

  # Wallet loading — spawned to avoid blocking
  def handle_info(:load_wallet, %{wallet_loaded: true} = state), do: {:noreply, state}

  def handle_info(:load_wallet, state) do
    case state.coin_auth do
      {:ok, auth} ->
        server = self()

        spawn(fn ->
          result = Litecoin.load_wallet(auth)
          send(server, {:load_wallet_result, result})
        end)

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:load_wallet_result, :ok}, state) do
    Logger.info("Litecoin wallet loaded successfully")
    state = %{state | wallet_loaded: true}
    maybe_reschedule(state, :poll_wallet_info, 1_000)

    state = schedule_transactions_poll(state, 3_000)
    {:noreply, state}
  end

  def handle_info({:load_wallet_result, {:error, message}}, state) do
    if is_binary(message) and String.contains?(message, "already loaded") do
      Logger.info("Litecoin wallet already loaded")
      state = %{state | wallet_loaded: true}
      maybe_reschedule(state, :poll_wallet_info, 1_000)
  
      state = schedule_transactions_poll(state, 3_000)
      {:noreply, state}
    else
      Logger.warning("Failed to load wallet: #{inspect(message)}, attempting to create...")

      case state.coin_auth do
        {:ok, auth} ->
          server = self()

          spawn(fn ->
            result = Litecoin.create_wallet(auth)
            send(server, {:create_wallet_result, result})
          end)

          {:noreply, state}

        _ ->
          {:noreply, state}
      end
    end
  end

  def handle_info({:create_wallet_result, :ok}, state) do
    Logger.info("Litecoin wallet created successfully")
    state = %{state | wallet_loaded: true}
    maybe_reschedule(state, :poll_wallet_info, 1_000)

    state = schedule_transactions_poll(state, 3_000)
    {:noreply, state}
  end

  def handle_info({:create_wallet_result, {:error, reason}}, state) do
    Logger.error("Failed to create wallet: #{inspect(reason)}")
    {:noreply, state}
  end

  def handle_info({:daemon_stop_result, {:ok, _response}}, state) do
    Logger.info("Litecoin daemon stopped successfully")

    state = %{
      state
      | daemon_status: :stopped,
        wallet_loaded: false,
        blocks: 0,
        blocks_synced: 0,
        headers: 0,
        headers_synced: 0,
        verification_progress: 0.0,
        daemon_warmup_status: nil,
        difficulty: 0,
        connections: 0,
        wallet_encryption_status: :wes_unknown,
        transactions: []
    }

    broadcast(state)
    {:noreply, state}
  end

  def handle_info({:daemon_stop_result, {:error, reason}}, state) do
    Logger.error("Failed to stop Litecoin daemon: #{inspect(reason)}")
    state = %{state | daemon_status: :running}
    broadcast(state)
    {:noreply, state}
  end

  def handle_info({:download_result, {:ok}}, state) do
    Logger.info("Litecoin download completed successfully")
    coin_auth = Litecoin.get_auth_values()

    state = %{
      state
      | downloading: false,
        download_complete: true,
        download_error: nil,
        coin_files_exist: true,
        coin_auth: coin_auth
    }

    broadcast(state)
    Process.send_after(self(), :clear_download_success, 5_000)
    {:noreply, state}
  end

  def handle_info({:download_result, {:error, reason}}, state) do
    Logger.error("Litecoin download failed: #{inspect(reason)}")

    state = %{
      state
      | downloading: false,
        download_complete: false,
        download_error: "Download failed: #{inspect(reason)}"
    }

    broadcast(state)
    {:noreply, state}
  end

  def handle_info(:poll_disk_usage, state) do
    {disk_used_bytes, disk_total_bytes} =
      case BoxWallet.Coins.CoinHelper.disk_free() do
        {:ok, %{total: total_mb, free: free_mb}} ->
          {(total_mb - free_mb) * 1_048_576, total_mb * 1_048_576}

        _ ->
          {state.disk_used_bytes, state.disk_total_bytes}
      end

    state = %{state | disk_used_bytes: disk_used_bytes, disk_total_bytes: disk_total_bytes}
    broadcast(state)
    Process.send_after(self(), :poll_disk_usage, @disk_usage_interval)
    {:noreply, state}
  end

  def handle_info(:clear_download_success, state) do
    state = %{state | download_complete: false}
    broadcast(state)
    {:noreply, state}
  end

  # --- Private ---

  defp schedule_polls do
    Process.send_after(self(), :poll_blockchain_info, 200)
    # Wallet info polling starts after wallet is loaded
    Process.send_after(self(), :poll_block_height, 400)
    Process.send_after(self(), :poll_peer_info, 600)
  end

  defp maybe_reschedule(%{polling_paused: true}, _message, _interval), do: :ok

  defp maybe_reschedule(%{daemon_status: status}, _message, _interval)
       when status not in [:starting, :running],
       do: :ok

  defp maybe_reschedule(_state, message, interval) do
    Process.send_after(self(), message, interval)
  end

  defp schedule_transactions_poll(state, delay) do
    if state.transactions_timer, do: Process.cancel_timer(state.transactions_timer)

    if state.polling_paused do
      %{state | transactions_timer: nil}
    else
      timer = Process.send_after(self(), :poll_transactions, delay)
      %{state | transactions_timer: timer}
    end
  end

  defp broadcast(state) do
    # Build the map that LiveViews will merge into assigns
    payload = %{
      coin_files_exist: state.coin_files_exist,
      coin_daemon_starting: state.daemon_status == :starting,
      coin_daemon_started: state.daemon_status == :running,
      coin_daemon_stopped: state.daemon_status == :stopped,
      coin_daemon_stopping: state.daemon_status == :stopping,
      blocks: state.blocks,
      headers: state.headers,
      blocks_synced: state.blocks_synced,
      headers_synced: state.headers_synced,
      verification_progress: state.verification_progress,
      daemon_warmup_status: state.daemon_warmup_status,
      difficulty: state.difficulty,
      connections: state.connections,
      block_height: state.block_height,
      balance: state.balance,
      unconfirmed_balance: state.unconfirmed_balance,
      immature_balance: state.immature_balance,
      blockchain_is_synced: state.blockchain_is_synced,
      wallet_encryption_status: state.wallet_encryption_status,
      downloading: state.downloading,
      download_complete: state.download_complete,
      download_error: state.download_error,
      transactions: state.transactions,
      disk_used_bytes: state.disk_used_bytes,
      disk_total_bytes: state.disk_total_bytes
    }

    Phoenix.PubSub.broadcast(Boxwallet.PubSub, "litecoin:status", {:litecoin_state, payload})
  end
end
