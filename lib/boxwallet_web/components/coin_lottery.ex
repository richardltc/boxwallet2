defmodule BoxwalletWeb.CoinLottery do
  use Phoenix.Component
  import BoxwalletWeb.CoreComponents

  @lottery_period 10_080
  @seconds_per_block 60
  @lottery_winners 11

  attr :color, :string, required: true
  attr :coin_daemon_started, :boolean, default: false
  attr :blockchain_is_synced, :boolean, default: false
  attr :blocks_synced, :integer, default: 0
  attr :balance, :float, default: 0.0
  attr :transactions, :list, default: []

  def coin_lottery(assigns) do
    last_block = last_lottery_block(assigns.blocks_synced)
    blocks_in_period = assigns.blocks_synced - last_block
    tickets = lottery_tickets(assigns.transactions, blocks_in_period)
    next_lottery = next_lottery_human(assigns.blocks_synced)
    win_chance = win_chance(tickets)

    assigns =
      assigns
      |> assign(:lottery_tickets, tickets)
      |> assign(:next_lottery, next_lottery)
      |> assign(:win_chance, win_chance)

    ~H"""
    <div class="flex flex-col items-start">
      <div class="flex items-center gap-1">
        <span class={["text-lg font-normal", @color]}>
          Lottery Tickets:
        </span>
        <.icon name="hero-ticket" class={@color <> " h-6 w-6"} />
        <span class="text-lg font-semibold">{@lottery_tickets}</span>
      </div>
      <span class="text-sm">
        <span class={@color}>Chance of winning:</span>
        <span class="text-gray-400">{@win_chance}%</span>
        <span class="text-gray-400">|</span>
        <span class={@color}>Next draw:</span>
        <span class="text-gray-400">{@next_lottery}</span>
      </span>
    </div>
    """
  end

  defp last_lottery_block(blocks) when blocks <= 0, do: 0

  defp last_lottery_block(blocks) do
    div(blocks, @lottery_period) * @lottery_period
  end

  defp next_lottery_human(blocks) when blocks <= 0, do: "..."

  defp next_lottery_human(blocks) do
    blocks_left = last_lottery_block(blocks) + @lottery_period - blocks
    seconds = blocks_left * @seconds_per_block
    seconds_to_human(seconds)
  end

  defp lottery_tickets(transactions, blocks_in_period) do
    Enum.count(transactions, fn tx ->
      tx.category == "stake_reward" and
        tx.confirmations >= 0 and
        tx.confirmations <= blocks_in_period
    end)
  end

  defp win_chance(0), do: "0.00"

  defp win_chance(tickets) do
    chance = (1 - :math.pow(1 - tickets / @lottery_period, @lottery_winners)) * 100
    :erlang.float_to_binary(chance, decimals: 2)
  end

  defp seconds_to_human(seconds) when seconds <= 0, do: "now"

  defp seconds_to_human(total_seconds) do
    weeks = div(total_seconds, 604_800)
    rem_after_weeks = rem(total_seconds, 604_800)
    days = div(rem_after_weeks, 86_400)
    rem_after_days = rem(rem_after_weeks, 86_400)
    hours = div(rem_after_days, 3_600)
    rem_after_hours = rem(rem_after_days, 3_600)
    minutes = div(rem_after_hours, 60)

    [{weeks, "week"}, {days, "day"}, {hours, "hour"}, {minutes, "minute"}]
    |> Enum.filter(fn {n, _} -> n > 0 end)
    |> Enum.map(fn {n, unit} -> plural(n, unit) end)
    |> Enum.join(" ")
    |> case do
      "" -> "< 1 minute"
      result -> result
    end
  end

  defp plural(1, unit), do: "1 #{unit}"
  defp plural(n, unit), do: "#{n} #{unit}s"
end
