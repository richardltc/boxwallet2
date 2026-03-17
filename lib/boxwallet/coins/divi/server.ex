defmodule Boxwallet.Coins.Divi.Server do
  use GenServer
  require Logger

  alias Boxwallet.Coins.Divi

  @get_info_interval 2_000
  @blockchain_info_interval 3_000
  @wallet_info_interval 5_000
  @mn_sync_interval 10_000
  @block_height_interval 60_000
  @peer_info_interval 15_000
  @transactions_interval_fast 3_000
  @transactions_interval_slow 15_000

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

  # --- GenServer Callbacks ---

  @impl true
  def init(:ok) do
    coin_auth = Divi.get_auth_values()
    coin_files_exist = Divi.files_exist()

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
      blocks: 0,
      headers: 0,
      blocks_synced: 0,
      headers_synced: 0,
      difficulty: 0,
      connections: 0,
      block_height: 0,
      blockchain_is_synced: false,
      balance: 0.0,
      unconfirmed_balance: 0.0,
      immature_balance: 0.0,
      staking_status: "Staking Not Active",
      wallet_encryption_status: :wes_unknown,
      coin_files_exist: coin_files_exist,
      downloading: false,
      download_complete: false,
      download_error: nil,
      version: "...",
      transactions: [],
      active_tab: :home,
      transactions_timer: nil,
      disk_used_bytes: disk_used_bytes,
      disk_total_bytes: disk_total_bytes
    }

    # Check if daemon is already running
    state =
      case coin_auth do
        {:ok, auth} ->
          if Divi.daemon_is_running(auth) do
            Logger.info("Divi daemon already running on init")
            schedule_polls()
            %{state | daemon_status: :running}
          else
            state
          end

        _ ->
          state
      end

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
    case Divi.start_daemon() do
      {:ok} ->
        Logger.info("Divi daemon starting...")
        state = %{state | daemon_status: :starting}
        broadcast(state)
        Process.send_after(self(), :poll_get_info, 2_000)
        Process.send_after(self(), :poll_block_height, 5_000)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Failed to start Divi daemon: #{inspect(reason)}")
        broadcast(state)
        {:noreply, state}
    end
  end

  def handle_cast(:stop_daemon, state) do
    case state.coin_auth do
      {:ok, auth} ->
        state = %{state | daemon_status: :stopping}
        broadcast(state)

        server = self()

        spawn(fn ->
          result = Divi.stop_daemon(auth)
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
      result = Divi.download_coin()
      send(server, {:download_result, result})
    end)

    {:noreply, state}
  end

  def handle_cast({:set_active_tab, tab}, state) do
    state = %{state | active_tab: tab}

    # Kick off an immediate poll when switching to transactions tab
    state =
      if tab == :transactions and state.daemon_status == :running do
        schedule_transactions_poll(state, 0)
      else
        state
      end

    {:noreply, state}
  end

  def handle_cast(:refresh, %{daemon_status: :running} = state) do
    send(self(), :poll_get_info)
    send(self(), :poll_wallet_info)
    {:noreply, state}
  end

  def handle_cast(:refresh, state), do: {:noreply, state}

  # Poll triggers — spawn the blocking RPC call so GenServer stays responsive
  @impl true
  def handle_info(:poll_get_info, %{daemon_status: status} = state)
      when status in [:starting, :running] do
    case state.coin_auth do
      {:ok, auth} ->
        server = self()

        spawn(fn ->
          result = Divi.get_info(auth)
          send(server, {:get_info_result, result})
        end)

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(:poll_get_info, state), do: {:noreply, state}

  def handle_info(:poll_blockchain_info, %{daemon_status: status} = state)
      when status in [:starting, :running] do
    case state.coin_auth do
      {:ok, auth} ->
        server = self()

        spawn(fn ->
          result = Divi.get_blockchain_info(auth)
          send(server, {:blockchain_info_result, result})
        end)

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(:poll_blockchain_info, state), do: {:noreply, state}

  def handle_info(:poll_wallet_info, %{daemon_status: status} = state)
      when status in [:starting, :running] do
    case state.coin_auth do
      {:ok, auth} ->
        server = self()

        spawn(fn ->
          result = Divi.get_wallet_info(auth)
          send(server, {:wallet_info_result, result})
        end)

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(:poll_wallet_info, state), do: {:noreply, state}

  def handle_info(:poll_mn_sync, %{daemon_status: status} = state)
      when status in [:starting, :running] do
    case state.coin_auth do
      {:ok, auth} ->
        server = self()

        spawn(fn ->
          result = Divi.get_mn_sync_status(auth)
          send(server, {:mn_sync_result, result})
        end)

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(:poll_mn_sync, state), do: {:noreply, state}

  def handle_info(:poll_peer_info, %{daemon_status: status} = state)
      when status in [:starting, :running] do
    case state.coin_auth do
      {:ok, auth} ->
        server = self()

        spawn(fn ->
          result = Divi.get_peer_info(auth)
          send(server, {:peer_info_result, result})
        end)

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(:poll_peer_info, state), do: {:noreply, state}

  def handle_info(:poll_block_height, %{daemon_status: status} = state)
      when status in [:starting, :running] do
    server = self()

    spawn(fn ->
      result = Divi.get_block_height()
      send(server, {:block_height_result, result})
    end)

    {:noreply, state}
  end

  def handle_info(:poll_block_height, state), do: {:noreply, state}

  def handle_info(:poll_transactions, %{daemon_status: status} = state)
      when status in [:starting, :running] do
    case state.coin_auth do
      {:ok, auth} ->
        server = self()

        spawn(fn ->
          result = Divi.list_transactions(auth)
          send(server, {:transactions_result, result})
        end)

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(:poll_transactions, state), do: {:noreply, state}

  # Results from spawned RPC calls
  def handle_info({:get_info_result, {:ok, response}}, state) do
    was_starting = state.daemon_status == :starting

    state = %{
      state
      | daemon_status: :running,
        connections: response.result.connections || 0,
        staking_status: response.result.staking_status || "Staking Not Active",
        version: response.result.version || "v..."
    }

    broadcast(state)

    # Always reschedule get_info
    Process.send_after(self(), :poll_get_info, @get_info_interval)

    # Only kick off the other polls on first transition from :starting to :running
    state =
      if was_starting do
        Process.send_after(self(), :poll_blockchain_info, @blockchain_info_interval)
        Process.send_after(self(), :poll_wallet_info, @wallet_info_interval)
        Process.send_after(self(), :poll_mn_sync, @mn_sync_interval)
        Process.send_after(self(), :poll_peer_info, @peer_info_interval)
        schedule_transactions_poll(state, 3_000)
      else
        state
      end

    {:noreply, state}
  end

  def handle_info({:get_info_result, {:error, _reason}}, state) do
    Logger.warning("Divi get_info poll failed, retrying...")
    Process.send_after(self(), :poll_get_info, 2_000)
    {:noreply, state}
  end

  def handle_info({:blockchain_info_result, {:ok, response}}, state) do
    state = %{
      state
      | blocks_synced: response.result.blocks || 0,
        blocks:
          Number.Delimit.number_to_delimited(response.result.blocks, precision: 0) || 0,
        difficulty:
          Number.Delimit.number_to_delimited(response.result.difficulty, precision: 0) || 0,
        headers_synced: response.result.headers || 0,
        headers:
          Number.Delimit.number_to_delimited(response.result.headers, precision: 0) || 0
    }

    broadcast(state)
    Process.send_after(self(), :poll_blockchain_info, @blockchain_info_interval)
    {:noreply, state}
  end

  def handle_info({:blockchain_info_result, {:error, _reason}}, state) do
    Logger.warning("Divi blockchain info poll failed, retrying...")
    Process.send_after(self(), :poll_blockchain_info, 2_000)
    {:noreply, state}
  end

  def handle_info({:wallet_info_result, {:ok, response}}, state) do
    wallet_encryption_status =
      case response.result.encryption_status do
        "unencrypted" -> :wes_unencrypted
        "unlocked" -> :wes_unlocked
        "locked" -> :wes_locked
        "unlocked-for-staking" -> :wes_unlocked_for_staking
        _ -> :wes_unknown
      end

    state = %{
      state
      | wallet_encryption_status: wallet_encryption_status,
        balance: response.result.balance,
        unconfirmed_balance: response.result.unconfirmed_balance || 0.0,
        immature_balance: response.result.immature_balance || 0.0
    }

    broadcast(state)
    Process.send_after(self(), :poll_wallet_info, @wallet_info_interval)
    {:noreply, state}
  end

  def handle_info({:wallet_info_result, {:error, _reason}}, state) do
    Logger.warning("Divi wallet info poll failed, retrying...")
    Process.send_after(self(), :poll_wallet_info, 2_000)
    {:noreply, state}
  end

  def handle_info({:mn_sync_result, {:ok, response}}, state) do
    state = %{state | blockchain_is_synced: response.result.is_blockchain_synced == true}
    broadcast(state)
    Process.send_after(self(), :poll_mn_sync, @mn_sync_interval)
    {:noreply, state}
  end

  def handle_info({:mn_sync_result, {:error, _reason}}, state) do
    Logger.warning("Divi MN sync poll failed, retrying...")
    Process.send_after(self(), :poll_mn_sync, @mn_sync_interval)
    {:noreply, state}
  end

  def handle_info({:block_height_result, {:ok, count}}, state) do
    state = %{state | block_height: count}
    broadcast(state)
    Process.send_after(self(), :poll_block_height, @block_height_interval)
    {:noreply, state}
  end

  def handle_info({:block_height_result, {:error, reason}}, state) do
    Logger.warning("Unable to get block height: #{inspect(reason)}, retrying in 65s")
    Process.send_after(self(), :poll_block_height, 65_000)
    {:noreply, state}
  end

  def handle_info({:peer_info_result, {:ok, %{max_synced_headers: _, max_synced_blocks: _}}}, state) do
    broadcast(state)
    Process.send_after(self(), :poll_peer_info, @peer_info_interval)
    {:noreply, state}
  end

  def handle_info({:peer_info_result, {:error, reason}}, state) do
    Logger.warning("Divi peer info poll failed: #{inspect(reason)}, retrying...")
    Process.send_after(self(), :poll_peer_info, @peer_info_interval)
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
    Logger.warning("Divi transactions poll failed: #{inspect(reason)}, retrying...")
    state = schedule_transactions_poll(state, @transactions_interval_slow)
    {:noreply, state}
  end

  def handle_info({:daemon_stop_result, {:ok, _response}}, state) do
    Logger.info("Divi daemon stopped successfully")

    state = %{
      state
      | daemon_status: :stopped,
        blocks: 0,
        blocks_synced: 0,
        headers: 0,
        headers_synced: 0,
        difficulty: 0,
        connections: 0,
        staking_status: "Staking Not Active",
        wallet_encryption_status: :wes_unknown,
        transactions: []
    }

    broadcast(state)
    {:noreply, state}
  end

  def handle_info({:daemon_stop_result, {:error, reason}}, state) do
    Logger.error("Failed to stop Divi daemon: #{inspect(reason)}")
    state = %{state | daemon_status: :running}
    broadcast(state)
    {:noreply, state}
  end

  def handle_info({:download_result, {:ok}}, state) do
    Logger.info("Divi download completed successfully")
    coin_auth = Divi.get_auth_values()

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
    Logger.error("Divi download failed: #{inspect(reason)}")

    state = %{
      state
      | downloading: false,
        download_complete: false,
        download_error: "Download failed: #{inspect(reason)}"
    }

    broadcast(state)
    {:noreply, state}
  end

  def handle_info(:clear_download_success, state) do
    state = %{state | download_complete: false}
    broadcast(state)
    {:noreply, state}
  end

  # --- Private ---

  defp schedule_transactions_poll(state, delay) do
    if state.transactions_timer, do: Process.cancel_timer(state.transactions_timer)
    timer = Process.send_after(self(), :poll_transactions, delay)
    %{state | transactions_timer: timer}
  end

  defp schedule_polls do
    Process.send_after(self(), :poll_get_info, 200)
    Process.send_after(self(), :poll_blockchain_info, 400)
    Process.send_after(self(), :poll_wallet_info, 600)
    Process.send_after(self(), :poll_mn_sync, 800)
    Process.send_after(self(), :poll_peer_info, 1_000)
    Process.send_after(self(), :poll_block_height, 1_200)
    Process.send_after(self(), :poll_transactions, 1_400)
  end

  defp broadcast(state) do
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
      difficulty: state.difficulty,
      connections: state.connections,
      block_height: state.block_height,
      balance: state.balance,
      unconfirmed_balance: state.unconfirmed_balance,
      immature_balance: state.immature_balance,
      blockchain_is_synced: state.blockchain_is_synced,
      staking_status: state.staking_status,
      wallet_encryption_status: state.wallet_encryption_status,
      downloading: state.downloading,
      download_complete: state.download_complete,
      download_error: state.download_error,
      version: state.version,
      transactions: state.transactions,
      disk_used_bytes: state.disk_used_bytes,
      disk_total_bytes: state.disk_total_bytes
    }

    Phoenix.PubSub.broadcast(Boxwallet.PubSub, "divi:status", {:divi_state, payload})
  end
end
