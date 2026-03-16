defmodule Boxwallet.Coins.Zano.Server do
  use GenServer
  require Logger

  alias Boxwallet.Coins.Zano

  @get_info_interval 3_000

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

  # --- GenServer Callbacks ---

  @impl true
  def init(:ok) do
    coin_auth = Zano.get_auth_values()
    coin_files_exist = Zano.files_exist()

    state = %{
      coin_auth: coin_auth,
      daemon_status: :stopped,
      coin_files_exist: coin_files_exist,
      downloading: false,
      download_complete: false,
      download_error: nil,
      connections: 0,
      blocks_synced: 0,
      headers_synced: 0,
      block_height: 0,
      blockchain_is_synced: false
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

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast(:start_daemon, state) do
    case Zano.start_daemon() do
      {:ok} ->
        Logger.info("Zano daemon starting...")
        state = %{state | daemon_status: :starting}
        broadcast(state)
        Process.send_after(self(), :poll_get_info, 2_000)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Failed to start Zano daemon: #{inspect(reason)}")
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
          result = Zano.stop_daemon(auth)
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
      result = Zano.download_coin()
      send(server, {:download_result, result})
    end)

    {:noreply, state}
  end

  # --- get_info polling ---

  @impl true
  def handle_info(:poll_get_info, %{daemon_status: status} = state)
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

  def handle_info({:get_info_result, {:ok, response}}, state) do
    r = response.result
    connections = (r.incoming_connections_count || 0) + (r.outgoing_connections_count || 0)
    blocks_synced = r.height || 0
    block_height = max(r.max_net_seen_height || 0, blocks_synced)

    state = %{
      state
      | daemon_status: :running,
        connections: connections,
        blocks_synced: blocks_synced,
        headers_synced: blocks_synced,
        block_height: block_height,
        blockchain_is_synced: block_height > 0 and blocks_synced >= block_height
    }

    broadcast(state)
    Process.send_after(self(), :poll_get_info, @get_info_interval)
    {:noreply, state}
  end

  def handle_info({:get_info_result, {:error, _reason}}, state) do
    Logger.warning("Zano get_info poll failed, retrying...")
    Process.send_after(self(), :poll_get_info, @get_info_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info({:daemon_stop_result, {:ok, _response}}, state) do
    Logger.info("Zano daemon stopped successfully")
    state = %{state | daemon_status: :stopped, connections: 0, blocks_synced: 0, headers_synced: 0, block_height: 0, blockchain_is_synced: false}
    broadcast(state)
    {:noreply, state}
  end

  def handle_info({:daemon_stop_result, {:error, reason}}, state) do
    Logger.error("Failed to stop Zano daemon: #{inspect(reason)}")
    state = %{state | daemon_status: :running}
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

  def handle_info(:clear_download_success, state) do
    state = %{state | download_complete: false}
    broadcast(state)
    {:noreply, state}
  end

  # --- Private ---

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
      blockchain_is_synced: state.blockchain_is_synced
    }

    Phoenix.PubSub.broadcast(Boxwallet.PubSub, "zano:status", {:zano_state, payload})
  end
end
