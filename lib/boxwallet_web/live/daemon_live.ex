# lib/my_app_web/live/daemon_live.ex
defmodule BoxWalletWeb.DaemonLive do
  use BoxwalletWeb, :live_view

  @coins [
    %{name: "Bitcoin", module: MyApp.Coins.Bitcoin},
    %{name: "Litecoin", module: MyApp.Coins.Litecoin}
    # Add more coins here
  ]

  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(5000, :update_sync)
    coin = List.first(@coins)
    status = if coin.module.daemon_running?(), do: "Running", else: "Stopped"

    {:ok,
     assign(socket,
       coins: @coins,
       selected_coin: coin,
       daemon_status: status,
       install_status: :not_started,
       sync_info: coin.module.get_sync_info()
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="container">
      <h1>Crypto Daemon Control</h1>
      <select phx-change="select_coin">
        <%= for coin <- @coins do %>
          <option value={coin.name} selected={@selected_coin.name == coin.name}>{coin.name}</option>
        <% end %>
      </select>
      <button phx-click="install_daemon" disabled={elem(@install_status, 0) == :in_progress}>
        {case @install_status do
          :completed -> "Daemon Installed"
          :in_progress -> "Installing..."
          {:failed, reason} -> "Install Failed: #{reason}"
          _ -> "Install Daemon"
        end}
      </button>
      <button phx-click="toggle_daemon">
        {if @daemon_status == "Running", do: "Stop Daemon", else: "Start Daemon"}
      </button>
      <p>Daemon Status: {@daemon_status}</p>
      <p>Install Status: {elem(@install_status, 0)}</p>

      <h2>{@selected_coin.name} Blockchain Sync</h2>
      <div class="progress-container">
        <div class="progress-bar" style={"width: #{@sync_info.progress}%"}>
          {@sync_info.progress}%
        </div>
      </div>
      <div class="counters">
        <div class="counter">
          <span>Blocks: </span><span class="number" data-count={@sync_info.blocks}><%= @sync_info.blocks %></span>
        </div>
        <div class="counter">
          <span>Headers: </span><span class="number" data-count={@sync_info.headers}><%= @sync_info.headers %></span>
        </div>
      </div>
    </div>

    <style>
      .container { max-width: 600px; margin: 0 auto; padding: 20px; font-family: Arial, sans-serif; }
      button, select { padding: 10px 20px; margin: 10px; cursor: pointer; }
      .progress-container {
        width: 100%;
        background: #e0e0e0;
        border-radius: 5px;
        overflow: hidden;
        margin: 20px 0;
      }
      .progress-bar {
        height: 30px;
        background: #4caf50;
        color: white;
        text-align: center;
        line-height: 30px;
        transition: width 0.5s ease-in-out;
      }
      .counters { display: flex; gap: 20px; margin-top: 20px; }
      .counter { font-size: 18px; }
      .number {
        display: inline-block;
        min-width: 100px;
        text-align: right;
        transition: all 0.5s ease-in-out;
      }
    </style>

    <script>
      document.addEventListener("DOMContentLoaded", () => {
        document.querySelectorAll('.number').forEach(element => {
          let start = parseInt(element.getAttribute('data-count') || '0');
          let end = parseInt(element.textContent);
          if (start !== end) {
            let duration = 500;
            let range = end - start;
            let current = start;
            let increment = range > 0 ? 1 : -1;
            let stepTime = Math.abs(Math.floor(duration / range));
            let timer = setInterval(() => {
              current += increment;
              element.textContent = current;
              element.setAttribute('data-count', current);
              if (current === end) clearInterval(timer);
            }, stepTime);
          }
        });
      });
    </script>
    """
  end

  def handle_event("select_coin", %{"value" => coin_name}, socket) do
    coin = Enum.find(@coins, &(&1.name == coin_name))
    status = if coin.module.daemon_running?(), do: "Running", else: "Stopped"

    {:noreply,
     assign(socket,
       selected_coin: coin,
       daemon_status: status,
       sync_info: coin.module.get_sync_info()
     )}
  end

  def handle_event("install_daemon", _params, socket) do
    socket = assign(socket, install_status: :in_progress)
    coin_module = socket.assigns.selected_coin.module

    Task.start(fn ->
      case coin_module.install_daemon() do
        :ok -> send(self(), :install_complete)
        {:error, reason} -> send(self(), {:install_failed, reason})
      end
    end)

    {:noreply, socket}
  end

  def handle_event("toggle_daemon", _params, socket) do
    coin_module = socket.assigns.selected_coin.module

    new_status =
      if coin_module.daemon_running?(),
        do:
          (
            coin_module.stop_daemon()
            "Stopped"
          ),
        else:
          (
            coin_module.start_daemon()
            "Running"
          )

    sync_info =
      if new_status == "Running",
        do: coin_module.get_sync_info(),
        else: %{blocks: 0, headers: 0, progress: 0}

    {:noreply, assign(socket, daemon_status: new_status, sync_info: sync_info)}
  end

  def handle_info(:update_sync, socket) do
    coin_module = socket.assigns.selected_coin.module

    sync_info =
      if socket.assigns.daemon_status == "Running",
        do: coin_module.get_sync_info(),
        else: %{blocks: 0, headers: 0, progress: 0}

    {:noreply, assign(socket, sync_info: sync_info)}
  end

  def handle_info(:install_complete, socket) do
    {:noreply, assign(socket, install_status: :completed)}
  end

  def handle_info({:install_failed, reason}, socket) do
    {:noreply, assign(socket, install_status: {:failed, reason})}
  end
end
