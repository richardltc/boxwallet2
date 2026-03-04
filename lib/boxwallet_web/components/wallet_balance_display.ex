defmodule BoxwalletWeb.WalletBalanceDisplay do
  use Phoenix.Component
  use Number
  import BoxwalletWeb.CoreComponents

  attr :balance, :float, required: true
  attr :hide_balance, :boolean, required: true
  attr :color, :string, default: "text-gray-500"

  def balance_display(assigns) do
    ~H"""
    <div class="relative flex items-baseline gap-1">
      <span class={["text-lg font-normal", @color]}>
        Balance:
      </span>

      <small class="badge text-3xl font-mono border-0">
        {if @hide_balance, do: "●●●●●●", else: Number.Delimit.number_to_delimited(@balance, precision: 2)}
      </small>

      <button
        phx-click="toggle_hide_balance"
        class={["ml-2 cursor-pointer hover:opacity-70", @color]}
        title={if @hide_balance, do: "Show balance", else: "Hide balance"}
      >
        <.icon name={if @hide_balance, do: "hero-eye-slash", else: "hero-eye"} class="h-5 w-5" />
      </button>
    </div>
    """
  end
end
