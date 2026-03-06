defmodule BoxwalletWeb.CoinTransactions do
  use Phoenix.Component
  import BoxwalletWeb.CoreComponents

  attr :color, :string, required: true
  attr :coin_daemon_started, :boolean, default: false

  def coin_transactions(assigns) do
    ~H"""
    <div class="border-t border-gray-100 pt-6">
      <p class={"text-lg font-semibold text-center " <> @color}>Transactions</p>

      <div class="flex justify-center gap-4 mt-4">
        <button
          class="btn btn-outline gap-2"
          phx-click="receive_address"
          disabled={!@coin_daemon_started}
          title={if @coin_daemon_started, do: "Get a new receive address", else: "Daemon not running"}
        >
          <.icon name="hero-arrow-down-tray" class="w-5 h-5" />
          Receive
        </button>
      </div>

      <p class="text-gray-400 mt-4 text-center">Transaction history coming soon</p>
    </div>
    """
  end
end
