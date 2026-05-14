defmodule Boxwallet.Coins.Zano.Server do
  use GenServer
  require Logger

  alias Boxwallet.Coins.Zano

  @get_info_interval 3_000
  @wallet_info_interval 5_000
  @transactions_interval_fast 3_000
  @transactions_interval_slow 15_000
  @block_height_interval 60_000
  @disk_usage_interval 60_000
  @walletd_call_timeout 25_000

  # --- Public API ---

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def get_state, do: GenServer.call(__MODULE__, :get_state)
  def start_daemon, do: GenServer.cast(__MODULE__, :start_daemon)
  def stop_daemon, do: GenServer.cast(__MODULE__, :stop_daemon)
  def download_coin, do: GenServer.cast(__MODULE__, :download_coin)
  def pause_polling, do: GenServer.cast(__MODULE__, :pause_polling)
  def resume_polling, do: GenServer.cast(__MODULE__, :resume_polling)
  def set_active_tab(tab), do: GenServer.cast(__MODULE__, {:set_active_tab, tab})

  def create_wallet(password) do
    GenServer.call(__MODULE__, {:create_wallet, password}, @walletd_call_timeout)
  end

  def start_walletd(password) do
    GenServer.call(__MODULE__, {:start_walletd, password}, @walletd_call_timeout)
  end

  def stop_walletd, do: GenServer.cast(__MODULE__, :stop_walletd)

  # --- GenServer Callbacks ---

  @impl true
  def init(:ok) do
    coin_auth = Zano.get_auth_values()
    coin_files_exist = Zano.files_exist()
    {disk_used_bytes, disk_total_bytes} = read_disk_usage()

    state = %{
      coin_auth: coin_auth,
      daemon_status: :stopped,
      walletd_status: :stopped,
      coin_files_exist: coin_files_exist,
      downloading: false,
      download_complete: false,
      download_error: nil,
      connections: 0,
      blocks_synced: 0,
      headers_synced: 0,
      block_height: 0,
      blockchain_is_synced: false,
      balance: 0.0,
      unconfirmed_balance: 0.0,
      immature_balance: 0.0,
      wallet_encryption_status: :wes_unknown,
      staking: false,
      transactions: [],
      receive_address: "",
      active_tab: :home,
      transactions_timer: nil,
      polling_paused: false,
      disk_used_bytes: disk_used_bytes,
      disk_total_bytes: disk_total_bytes
    }

    state =
      case coin_auth do
        {:ok, auth} ->
          if Zano.daemon_is_running(auth) do
            Logger.info("Zano daemon already running on init")
            Process.send_after(self(), :poll_get_info, 200)
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
    {used, total} = read_disk_usage()
    state = %{state | disk_used_bytes: used, disk_total_bytes: total}
    {:reply, state, state}
  end

  def handle_call({:create_wallet, password}, _from, state) do
    state = %{state | walletd_status: :starting}
    broadcast(state)

    case Zano.create_wallet(password) do
      :ok ->
        state = mark_walletd_running(state)
        broadcast(state)
        Process.send_after(self(), :poll_wallet_info, 500)
        Process.send_after(self(), :poll_transactions, 1_500)
        {:reply, :ok, state}

      {:error, reason} ->
        state = %{state | walletd_status: :stopped}
        broadcast(state)
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:start_walletd, password}, _from, state) do
    state = %{state | walletd_status: :starting}
    broadcast(state)

    case Zano.start_walletd(password) do
      :ok ->
        state = mark_walletd_running(state)
        broadcast(state)
        Process.send_after(self(), :poll_wallet_info, 500)
        Process.send_after(self(), :poll_transactions, 1_500)
        {:reply, :ok, state}

      {:error, reason} ->
        state = %{state | walletd_status: :stopped}
        broadcast(state)
        {:reply, {:error, reason}, state}
    end
  end

  defp mark_walletd_running(state) do
    %{
      state
      | walletd_status: :running,
        wallet_encryption_status: :wes_unlocked,
        staking: true
    }
  end

  @impl true
  def handle_cast(:start_daemon, state) do
    case Zano.start_daemon() do
      :ok ->
        Logger.info("Zano daemon starting...")
        state = %{state | daemon_status: :starting}
        broadcast(state)
        Process.send_after(self(), :poll_get_info, 2_000)
        Process.send_after(self(), :poll_block_height, 5_000)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Zano daemon failed to start: #{reason}")
        broadcast(state)
        {:noreply, state}
    end
  end

  def handle_cast(:stop_daemon, state) do
    case state.coin_auth do
      {:ok, auth} ->
        state = %{state | daemon_status: :stopping, walletd_status: :stopping}
        broadcast(state)

        server = self()

        spawn(fn ->
          result = Zano.stop_daemon(auth)
          send(server, {:daemon_stop_result, result})
        end)

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_cast(:stop_walletd, state) do
    state = %{state | walletd_status: :stopping}
    broadcast(state)

    server = self()

    spawn(fn ->
      Zano.stop_walletd()
      send(server, :walletd_stopped)
    end)

    {:noreply, state}
  end

  def handle_cast({:set_active_tab, tab}, state) do
    state = %{state | active_tab: tab}

    state =
      if tab == :transactions and state.walletd_status == :running do
        schedule_transactions_poll(state, 0)
      else
        state
      end

    {:noreply, state}
  end

  def handle_cast(:pause_polling, state) do
    Logger.info("Zano polling paused")
    {:noreply, %{state | polling_paused: true}}
  end

  def handle_cast(:resume_polling, state) do
    was_paused = state.polling_paused
    state = %{state | polling_paused: false}

    if was_paused and state.daemon_status in [:starting, :running] do
      Logger.info("Zano polling resumed")
      Process.send_after(self(), :poll_get_info, 200)

      if state.walletd_status == :running do
        Process.send_after(self(), :poll_wallet_info, 400)
        schedule_transactions_poll(state, 600)
      end
    end

    {:noreply, state}
  end

  def handle_cast(:download_coin, state) do
    state = %{state | downloading: true, download_complete: false, download_error: nil}
    broadcast(state)

    server = self()

    spawn(fn ->
      result = Zano.download_coin()
      send(server, {:download_result, result})
    end)

    {:noreply, state}
  end

  # --- Poll triggers ---

  @impl true
  def handle_info(:poll_get_info, %{daemon_status: status, polling_paused: false} = state)
      when status in [:starting, :running] do
    case state.coin_auth do
      {:ok, auth} ->
        server = self()

        spawn(fn ->
          result = Zano.get_info(auth)
          send(server, {:get_info_result, result})
        end)

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(:poll_get_info, state), do: {:noreply, state}

  def handle_info(:poll_wallet_info, %{walletd_status: :running, polling_paused: false} = state) do
    case state.coin_auth do
      {:ok, auth} ->
        server = self()

        spawn(fn ->
          result = Zano.get_wallet_info(auth)
          send(server, {:wallet_info_result, result})
        end)

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(:poll_wallet_info, state), do: {:noreply, state}

  def handle_info(:poll_transactions, %{walletd_status: :running, polling_paused: false} = state) do
    case state.coin_auth do
      {:ok, auth} ->
        server = self()
        current_height = state.block_height

        spawn(fn ->
          result = Zano.list_transactions(auth, current_height)
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
      result = Zano.get_block_height()
      send(server, {:block_height_result, result})
    end)

    {:noreply, state}
  end

  def handle_info(:poll_block_height, state), do: {:noreply, state}

  # --- RPC results ---

  def handle_info({:get_info_result, {:ok, response}}, state) do
    was_starting = state.daemon_status == :starting
    r = response.result || %BoxWallet.Coins.Zano.GetInfo.Result{}

    connections = (r.incoming_connections_count || 0) + (r.outgoing_connections_count || 0)
    blocks_synced = r.height || 0
    block_height = max(r.max_net_seen_height || 0, max(blocks_synced, state.block_height))

    wallet_encryption_status =
      cond do
        state.walletd_status == :running -> state.wallet_encryption_status
        Zano.wallet_file_exists?() -> :wes_locked
        true -> :wes_unencrypted
      end

    state = %{
      state
      | daemon_status: :running,
        connections: connections,
        blocks_synced: blocks_synced,
        headers_synced: blocks_synced,
        block_height: block_height,
        blockchain_is_synced: block_height > 0 and blocks_synced >= block_height,
        wallet_encryption_status: wallet_encryption_status
    }

    broadcast(state)
    maybe_reschedule(state, :poll_get_info, @get_info_interval)

    if was_starting do
      # Auto-start walletd polls if it's already running (e.g. re-attach after app restart)
      if Zano.walletd_is_running() do
        Process.send_after(self(), :poll_wallet_info, 300)
        Process.send_after(self(), :poll_transactions, 600)
        broadcast(%{state | walletd_status: :running, wallet_encryption_status: :wes_unlocked})
      end
    end

    {:noreply, state}
  end

  def handle_info({:get_info_result, {:error, _reason}}, state) do
    Logger.warning("Zano get_info poll failed, retrying...")
    maybe_reschedule(state, :poll_get_info, @get_info_interval)
    {:noreply, state}
  end

  def handle_info({:wallet_info_result, {:ok, response}}, state) do
    r = response.result

    state = %{
      state
      | balance: r.balance,
        unconfirmed_balance: r.unconfirmed_balance,
        immature_balance: r.immature_balance,
        receive_address: r.address,
        walletd_status: :running,
        wallet_encryption_status: :wes_unlocked,
        staking: true
    }

    broadcast(state)
    maybe_reschedule_walletd(state, :poll_wallet_info, @wallet_info_interval)
    {:noreply, state}
  end

  def handle_info({:wallet_info_result, {:error, reason}}, state) do
    Logger.warning("Zano wallet info poll failed: #{inspect(reason)}")

    state =
      if state.walletd_status == :running do
        %{
          state
          | walletd_status: :stopped,
            wallet_encryption_status:
              if(Zano.wallet_file_exists?(), do: :wes_locked, else: :wes_unencrypted),
            staking: false,
            balance: 0.0,
            unconfirmed_balance: 0.0,
            immature_balance: 0.0,
            receive_address: ""
        }
      else
        state
      end

    broadcast(state)
    maybe_reschedule_walletd(state, :poll_wallet_info, @wallet_info_interval)
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
    Logger.warning("Zano transactions poll failed: #{inspect(reason)}")
    state = schedule_transactions_poll(state, @transactions_interval_slow)
    {:noreply, state}
  end

  def handle_info({:block_height_result, {:ok, count}}, state) do
    state = %{state | block_height: max(state.block_height, count)}
    broadcast(state)
    maybe_reschedule(state, :poll_block_height, @block_height_interval)
    {:noreply, state}
  end

  def handle_info({:block_height_result, {:error, reason}}, state) do
    Logger.warning("Zano block_height poll failed: #{inspect(reason)}")
    maybe_reschedule(state, :poll_block_height, @block_height_interval)
    {:noreply, state}
  end

  def handle_info({:daemon_stop_result, {:ok, _response}}, state) do
    Logger.info("Zano daemon stopped successfully")

    state = %{
      state
      | daemon_status: :stopped,
        walletd_status: :stopped,
        connections: 0,
        blocks_synced: 0,
        headers_synced: 0,
        block_height: 0,
        blockchain_is_synced: false,
        wallet_encryption_status: :wes_unknown,
        staking: false,
        balance: 0.0,
        unconfirmed_balance: 0.0,
        immature_balance: 0.0,
        transactions: [],
        receive_address: ""
    }

    broadcast(state)
    {:noreply, state}
  end

  def handle_info({:daemon_stop_result, {:error, reason}}, state) do
    Logger.error("Failed to stop Zano daemon: #{inspect(reason)}")
    state = %{state | daemon_status: :running, walletd_status: state.walletd_status}
    broadcast(state)
    {:noreply, state}
  end

  def handle_info(:walletd_stopped, state) do
    Logger.info("Zano wallet daemon stopped")

    state = %{
      state
      | walletd_status: :stopped,
        wallet_encryption_status:
          if(Zano.wallet_file_exists?(), do: :wes_locked, else: :wes_unencrypted),
        staking: false,
        balance: 0.0,
        unconfirmed_balance: 0.0,
        immature_balance: 0.0,
        receive_address: ""
    }

    broadcast(state)
    {:noreply, state}
  end

  def handle_info({:download_result, {:ok}}, state) do
    Logger.info("Zano download completed successfully")
    coin_auth = Zano.get_auth_values()

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
    Logger.error("Zano download failed: #{inspect(reason)}")

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
    {used, total} = read_disk_usage()

    state = %{
      state
      | disk_used_bytes: used || state.disk_used_bytes,
        disk_total_bytes: total || state.disk_total_bytes
    }

    broadcast(state)
    Process.send_after(self(), :poll_disk_usage, @disk_usage_interval)
    {:noreply, state}
  end

  def handle_info(:clear_download_success, state) do
    state = %{state | download_complete: false}
    broadcast(state)
    {:noreply, state}
  end

  # --- Private helpers ---

  defp maybe_reschedule(%{polling_paused: true}, _msg, _i), do: :ok

  defp maybe_reschedule(%{daemon_status: status}, _msg, _i)
       when status not in [:starting, :running],
       do: :ok

  defp maybe_reschedule(_state, message, interval) do
    Process.send_after(self(), message, interval)
  end

  defp maybe_reschedule_walletd(%{polling_paused: true}, _msg, _i), do: :ok

  defp maybe_reschedule_walletd(%{walletd_status: :running}, msg, i),
    do: Process.send_after(self(), msg, i)

  defp maybe_reschedule_walletd(_state, _msg, _i), do: :ok

  defp schedule_transactions_poll(state, delay) do
    if state.transactions_timer, do: Process.cancel_timer(state.transactions_timer)

    if state.polling_paused or state.walletd_status != :running do
      %{state | transactions_timer: nil}
    else
      timer = Process.send_after(self(), :poll_transactions, delay)
      %{state | transactions_timer: timer}
    end
  end

  defp read_disk_usage do
    case BoxWallet.Coins.CoinHelper.disk_free() do
      {:ok, %{total: total_mb, free: free_mb}} ->
        {(total_mb - free_mb) * 1_048_576, total_mb * 1_048_576}

      _ ->
        {0, 0}
    end
  end

  defp broadcast(state) do
    payload = %{
      coin_files_exist: state.coin_files_exist,
      coin_daemon_starting: state.daemon_status == :starting,
      coin_daemon_started: state.daemon_status == :running,
      coin_daemon_stopped: state.daemon_status == :stopped,
      coin_daemon_stopping: state.daemon_status == :stopping,
      downloading: state.downloading,
      download_complete: state.download_complete,
      download_error: state.download_error,
      connections: state.connections,
      blocks_synced: state.blocks_synced,
      headers_synced: state.headers_synced,
      block_height: state.block_height,
      blockchain_is_synced: state.blockchain_is_synced,
      balance: state.balance,
      unconfirmed_balance: state.unconfirmed_balance,
      immature_balance: state.immature_balance,
      wallet_encryption_status: state.wallet_encryption_status,
      staking: state.staking,
      transactions: state.transactions,
      receive_address: state.receive_address,
      disk_used_bytes: state.disk_used_bytes,
      disk_total_bytes: state.disk_total_bytes
    }

    Phoenix.PubSub.broadcast(Boxwallet.PubSub, "zano:status", {:zano_state, payload})
  end
end
