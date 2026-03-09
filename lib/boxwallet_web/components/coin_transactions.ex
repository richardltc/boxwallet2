defmodule BoxwalletWeb.CoinTransactions do
  use Phoenix.Component
  import BoxwalletWeb.CoreComponents

  attr :color, :string, required: true
  attr :coin_daemon_started, :boolean, default: false
  attr :transactions, :list, default: []
  attr :confirmed_after, :integer, default: 6

  def coin_transactions(assigns) do
    ~H"""
    <div class="border-t border-gray-100 pt-6">
      <p class={"text-lg font-semibold text-center " <> @color}>Transactions</p>

      <div class="flex justify-center gap-4 mt-4">
        <button
          class="btn btn-outline btn-boxwalletgreen px-8 disabled:opacity-40"
          phx-click="receive_address"
          disabled={!@coin_daemon_started}
          title={if @coin_daemon_started, do: "Get a new receive address", else: "Daemon not running"}
        >
          <span class="hero-arrow-down-tray h-6 w-6" /> Receive
        </button>
      </div>

      <div :if={@transactions != []} class="mt-4 divide-y divide-base-300">
        <.transaction :for={tx <- Enum.reverse(@transactions)} transaction={tx} confirmed_after={@confirmed_after} />
      </div>

      <p :if={@transactions == []} class="text-gray-400 mt-4 text-center">
        No transactions yet
      </p>
    </div>
    """
  end

  attr :transaction, :map, required: true
  attr :confirmed_after, :integer, required: true

  def transaction(assigns) do
    assigns = assign(assigns, :formatted_time, format_blocktime(assigns.transaction.blocktime))

    ~H"""
    <div class="flex items-center gap-3 px-4 py-3">
      <div class="flex-shrink-0">
        <%= if @transaction.category == "receive" do %>
          <.icon name="hero-arrow-down" class="w-5 h-5 text-green-500" />
        <% else %>
          <.icon name="hero-arrow-up" class="w-5 h-5 text-red-500" />
        <% end %>
      </div>

      <div class="flex-1 min-w-0">
        <p class="text-sm font-medium truncate">
          {format_amount(@transaction.amount)}
        </p>
        <p class="text-xs text-gray-400">
          {@formatted_time}
        </p>
        <p class="text-xs text-gray-400 truncate">
          Received on: <span class="font-mono">{@transaction.address}</span>
        </p>
      </div>

      <div class="flex-shrink-0">
        <%= if @transaction.confirmations >= @confirmed_after do %>
          <span class="badge badge-success badge-sm">Confirmed</span>
        <% else %>
          <span class="badge badge-warning badge-sm">Confirming ({@transaction.confirmations}/{@confirmed_after})</span>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_amount(amount) when amount >= 0, do: "+#{:erlang.float_to_binary(amount, decimals: 2)}"
  defp format_amount(amount), do: :erlang.float_to_binary(amount, decimals: 2)

  defp format_blocktime(nil), do: "Pending"

  defp format_blocktime(unix_time) do
    {:ok, dt} = DateTime.from_unix(unix_time)
    now = DateTime.utc_now()
    today = DateTime.to_date(now)
    tx_date = DateTime.to_date(dt)
    time_str = Calendar.strftime(dt, "%H:%M")

    cond do
      tx_date == today ->
        "Today at #{time_str}"

      tx_date == Date.add(today, -1) ->
        "Yesterday at #{time_str}"

      true ->
        Calendar.strftime(dt, "%d %b %Y at %H:%M")
    end
  end
end
