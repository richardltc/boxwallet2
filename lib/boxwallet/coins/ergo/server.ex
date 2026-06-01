defmodule Boxwallet.Coins.Ergo.Server do
  @moduledoc """
  GenServer that owns Ergo daemon state and polling, broadcasting updates to
  `ErgoLive` over the `"ergo:status"` PubSub topic.

  Modelled on `Boxwallet.Coins.Litecoin.Server` (Ergo, like Litecoin, has no
  staking) but adapted to Ergo's REST API:

    * `:poll_info` — one `GET /info` call covers blocks, headers, peer count
      and sync progress (no separate peer-info / block-height polls).
    * `:poll_wallet_status` — wallet initialised? locked/unlocked?
    * `:poll_balances` — confirmed balance (nanoERG -> ERG).
    * `:poll_transactions` — wallet tx history.

  There is no auto load/create wallet flow: the user creates or restores a
  wallet (with its mnemonic) explicitly from the UI.
  """
  use GenServer
  require Logger

  alias Boxwallet.Coins.Ergo
  alias BoxWallet.Coins.Ergo.WalletBalances

  @info_interval 3_000
  @wallet_status_interval 5_000
  @balances_interval 5_000
  @transactions_interval_fast 3_000
  @transactions_interval_slow 15_000
  @disk_usage_interval 60_000

  # --- Public API ---

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def get_state, do: GenServer.call(__MODULE__, :get_state)
  def start_daemon, do: GenServer.cast(__MODULE__, :start_daemon)
  def stop_daemon, do: GenServer.cast(__MODULE__, :stop_daemon)
  def download_coin, do: GenServer.cast(__MODULE__, :download_coin)
  def refresh, do: GenServer.cast(__MODULE__, :refresh)
  def set_active_tab(tab), do: GenServer.cast(__MODULE__, {:set_active_tab, tab})
  def pause_polling, do: GenServer.cast(__MODULE__, :pause_polling)
  def resume_polling, do: GenServer.cast(__MODULE__, :resume_polling)

  # --- GenServer callbacks ---

  @impl true
  def init(:ok) do
    coin_auth = Ergo.get_auth_values()
    coin_files_exist = Ergo.files_exist()

    {disk_used_bytes, disk_total_bytes} = disk_usage({0, 0})

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
      wallet_initialized: false,
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

    state =
      case coin_auth do
        {:ok, auth} ->
          if Ergo.daemon_is_running(auth) do
            Logger.info("[ERG] Ergo node already running on init")
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
      disk_usage({state.disk_used_bytes, state.disk_total_bytes})

    state = %{state | disk_used_bytes: disk_used_bytes, disk_total_bytes: disk_total_bytes}
    {:reply, state, state}
  end

  @impl true
  def handle_cast(:start_daemon, state) do
    Ergo.start_daemon()
    Logger.info("[ERG] Ergo node starting...")
    state = %{state | daemon_status: :starting}
    broadcast(state)
    Process.send_after(self(), :poll_info, 2_000)
    {:noreply, state}
  end

  def handle_cast(:stop_daemon, state) do
    case state.coin_auth do
      {:ok, auth} ->
        state = %{state | daemon_status: :stopping}
        broadcast(state)
        server = self()

        spawn(fn -> send(server, {:daemon_stop_result, Ergo.stop_daemon(auth)}) end)
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_cast(:download_coin, state) do
    state = %{state | downloading: true, download_complete: false, download_error: nil}
    broadcast(state)
    server = self()

    spawn(fn -> send(server, {:download_result, Ergo.download_coin()}) end)
    {:noreply, state}
  end

  def handle_cast({:set_active_tab, tab}, state) do
    state = %{state | active_tab: tab}

    state =
      if tab == :transactions and state.daemon_status == :running do
        schedule_transactions_poll(state, 0)
      else
        state
      end

    {:noreply, state}
  end

  def handle_cast(:pause_polling, state) do
    Logger.info("[ERG] Ergo polling paused")
    {:noreply, %{state | polling_paused: true}}
  end

  def handle_cast(:resume_polling, state) do
    state = %{state | polling_paused: false}

    if state.daemon_status in [:starting, :running] do
      Logger.info("[ERG] Ergo polling resumed")
      schedule_polls()
      state = schedule_transactions_poll(state, 3_000)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  def handle_cast(:refresh, %{daemon_status: :running} = state) do
    send(self(), :poll_info)
    send(self(), :poll_wallet_status)
    send(self(), :poll_balances)
    {:noreply, state}
  end

  def handle_cast(:refresh, state), do: {:noreply, state}

  # --- Poll triggers (spawn the blocking call so the GenServer stays responsive) ---

  @impl true
  def handle_info(:poll_info, %{daemon_status: status, polling_paused: false} = state)
      when status in [:starting, :running] do
    spawn_poll(state, :poll_info, &Ergo.get_info/1, :info_result)
  end

  def handle_info(:poll_info, state), do: {:noreply, state}

  def handle_info(:poll_wallet_status, %{daemon_status: status, polling_paused: false} = state)
      when status in [:starting, :running] do
    spawn_poll(state, :poll_wallet_status, &Ergo.wallet_status/1, :wallet_status_result)
  end

  def handle_info(:poll_wallet_status, state), do: {:noreply, state}

  def handle_info(:poll_balances, %{daemon_status: status, polling_paused: false} = state)
      when status in [:starting, :running] do
    spawn_poll(state, :poll_balances, &Ergo.wallet_balances/1, :balances_result)
  end

  def handle_info(:poll_balances, state), do: {:noreply, state}

  def handle_info(:poll_transactions, %{daemon_status: status, polling_paused: false} = state)
      when status in [:starting, :running] do
    case state.coin_auth do
      {:ok, auth} ->
        server = self()
        spawn(fn -> send(server, {:transactions_result, Ergo.list_transactions(auth)}) end)
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(:poll_transactions, state), do: {:noreply, state}

  # --- Poll results ---

  def handle_info({:info_result, {:ok, info}}, state) do
    # Now that the API is responding, kick off wallet polling.
    if state.daemon_status == :starting do
      Process.send_after(self(), :poll_wallet_status, 200)
      Process.send_after(self(), :poll_balances, 400)
      send(self(), {:__schedule_tx, 600})
    end

    full_height = info.full_height || 0
    max_height = info.max_peer_height || 0

    state = %{
      state
      | daemon_status: running_if_active(state.daemon_status),
        blocks_synced: full_height,
        blocks: Number.Delimit.number_to_delimited(full_height, precision: 0),
        headers_synced: info.headers_height || 0,
        headers: Number.Delimit.number_to_delimited(info.headers_height || 0, precision: 0),
        block_height: max_height,
        difficulty: Number.Delimit.number_to_delimited(info.difficulty || 0, precision: 0),
        connections: info.peers_count || 0,
        blockchain_is_synced: full_height > 0 and max_height > 0 and full_height >= max_height
    }

    broadcast(state)
    maybe_reschedule(state, :poll_info, @info_interval)
    {:noreply, state}
  end

  def handle_info({:info_result, {:error, _reason}}, state) do
    Logger.warning("[ERG] Ergo /info poll failed, retrying...")
    maybe_reschedule(state, :poll_info, 2_000)
    {:noreply, state}
  end

  def handle_info({:__schedule_tx, delay}, state) do
    {:noreply, schedule_transactions_poll(state, delay)}
  end

  def handle_info({:wallet_status_result, {:ok, ws}}, state) do
    wallet_encryption_status =
      cond do
        ws.is_initialized != true -> :wes_unencrypted
        ws.is_unlocked == true -> :wes_unlocked
        true -> :wes_locked
      end

    state = %{
      state
      | wallet_initialized: ws.is_initialized == true,
        wallet_encryption_status: wallet_encryption_status
    }

    broadcast(state)
    maybe_reschedule(state, :poll_wallet_status, @wallet_status_interval)
    {:noreply, state}
  end

  def handle_info({:wallet_status_result, {:error, _reason}}, state) do
    maybe_reschedule(state, :poll_wallet_status, 2_000)
    {:noreply, state}
  end

  def handle_info({:balances_result, {:ok, %WalletBalances{} = balances}}, state) do
    state = %{state | balance: WalletBalances.balance_erg(balances)}
    broadcast(state)
    maybe_reschedule(state, :poll_balances, @balances_interval)
    {:noreply, state}
  end

  def handle_info({:balances_result, {:error, _reason}}, state) do
    # Commonly fails until the wallet is initialised/unlocked — retry quietly.
    maybe_reschedule(state, :poll_balances, @balances_interval)
    {:noreply, state}
  end

  def handle_info({:transactions_result, {:ok, transactions}}, state) do
    state = %{state | transactions: transactions}
    broadcast(state)

    interval =
      if state.active_tab == :transactions,
        do: @transactions_interval_fast,
        else: @transactions_interval_slow

    {:noreply, schedule_transactions_poll(state, interval)}
  end

  def handle_info({:transactions_result, {:error, _reason}}, state) do
    {:noreply, schedule_transactions_poll(state, @transactions_interval_slow)}
  end

  def handle_info({:daemon_stop_result, {:ok, _}}, state) do
    Logger.info("[ERG] Ergo node stopped successfully")

    state = %{
      state
      | daemon_status: :stopped,
        blocks: 0,
        blocks_synced: 0,
        headers: 0,
        headers_synced: 0,
        difficulty: 0,
        connections: 0,
        balance: 0.0,
        wallet_initialized: false,
        wallet_encryption_status: :wes_unknown,
        transactions: []
    }

    broadcast(state)
    {:noreply, state}
  end

  def handle_info({:daemon_stop_result, {:error, reason}}, state) do
    Logger.error("[ERG] Failed to stop Ergo node: #{inspect(reason)}")
    state = %{state | daemon_status: :running}
    broadcast(state)
    {:noreply, state}
  end

  def handle_info({:download_result, {:ok}}, state) do
    Logger.info("[ERG] Ergo download completed successfully")

    state = %{
      state
      | downloading: false,
        download_complete: true,
        download_error: nil,
        coin_files_exist: true,
        coin_auth: Ergo.get_auth_values()
    }

    broadcast(state)
    Process.send_after(self(), :clear_download_success, 5_000)
    {:noreply, state}
  end

  def handle_info({:download_result, {:error, reason}}, state) do
    Logger.error("[ERG] Ergo download failed: #{inspect(reason)}")

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

  def handle_info(:poll_disk_usage, state) do
    {disk_used_bytes, disk_total_bytes} =
      disk_usage({state.disk_used_bytes, state.disk_total_bytes})

    state = %{state | disk_used_bytes: disk_used_bytes, disk_total_bytes: disk_total_bytes}
    broadcast(state)
    Process.send_after(self(), :poll_disk_usage, @disk_usage_interval)
    {:noreply, state}
  end

  # --- Private ---

  defp spawn_poll(state, _message, fun, result_tag) do
    case state.coin_auth do
      {:ok, auth} ->
        server = self()
        spawn(fn -> send(server, {result_tag, fun.(auth)}) end)
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  defp running_if_active(status) when status in [:starting, :running], do: :running
  defp running_if_active(status), do: status

  defp schedule_polls do
    Process.send_after(self(), :poll_info, 200)
    Process.send_after(self(), :poll_wallet_status, 400)
    Process.send_after(self(), :poll_balances, 600)
  end

  defp maybe_reschedule(%{polling_paused: true}, _message, _interval), do: :ok

  defp maybe_reschedule(%{daemon_status: status}, _message, _interval)
       when status not in [:starting, :running],
       do: :ok

  defp maybe_reschedule(_state, message, interval),
    do: Process.send_after(self(), message, interval)

  defp schedule_transactions_poll(state, delay) do
    if state.transactions_timer, do: Process.cancel_timer(state.transactions_timer)

    if state.polling_paused do
      %{state | transactions_timer: nil}
    else
      timer = Process.send_after(self(), :poll_transactions, delay)
      %{state | transactions_timer: timer}
    end
  end

  defp disk_usage(fallback) do
    case BoxWallet.Coins.CoinHelper.disk_free() do
      {:ok, %{total: total_mb, free: free_mb}} ->
        {(total_mb - free_mb) * 1_048_576, total_mb * 1_048_576}

      _ ->
        fallback
    end
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
      blockchain_is_synced: state.blockchain_is_synced,
      wallet_initialized: state.wallet_initialized,
      wallet_encryption_status: state.wallet_encryption_status,
      downloading: state.downloading,
      download_complete: state.download_complete,
      download_error: state.download_error,
      transactions: state.transactions,
      disk_used_bytes: state.disk_used_bytes,
      disk_total_bytes: state.disk_total_bytes
    }

    Phoenix.PubSub.broadcast(Boxwallet.PubSub, "ergo:status", {:ergo_state, payload})
  end
end
