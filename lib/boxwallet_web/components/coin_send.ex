defmodule BoxwalletWeb.CoinSend do
  use Phoenix.Component
  import BoxwalletWeb.CoreComponents

  attr :color, :string, required: true
  attr :coin_daemon_started, :boolean, default: false
  attr :coming_soon, :boolean, default: false

  def coin_send(assigns) do
    ~H"""
    <div class="border-t border-gray-100 pt-6">
      <p class={"text-lg font-semibold text-center " <> @color}>Send</p>

      <%= if @coming_soon do %>
        <div class="flex justify-center mt-6">
          <button class="btn btn-outline btn-boxwalletgreen px-8 cursor-not-allowed" disabled title="Coming soon">
            <span class="hero-paper-airplane h-6 w-6" /> Send
            <span class="badge badge-sm ml-1">Coming soon</span>
          </button>
        </div>
      <% else %>
        <form phx-submit="send_coin" class="mt-6 max-w-lg mx-auto space-y-4">
          <div>
            <label class="label text-sm font-medium">Address</label>
            <input
              type="text"
              name="address"
              placeholder="Enter recipient address"
              class="input input-bordered w-full"
              required
              disabled={!@coin_daemon_started}
            />
          </div>

          <div>
            <label class="label text-sm font-medium">Amount</label>
            <input
              type="number"
              name="amount"
              placeholder="0.00"
              step="any"
              min="0"
              class="input input-bordered w-full"
              required
              disabled={!@coin_daemon_started}
            />
          </div>

          <div class="flex justify-center pt-2">
            <button
              type="submit"
              class="btn btn-outline btn-boxwalletgreen px-8"
              disabled={!@coin_daemon_started}
              title={if @coin_daemon_started, do: "Send coins", else: "Daemon not running"}
            >
              <span class="hero-paper-airplane h-6 w-6" /> Send
            </button>
          </div>
        </form>
      <% end %>
    </div>
    """
  end
end
