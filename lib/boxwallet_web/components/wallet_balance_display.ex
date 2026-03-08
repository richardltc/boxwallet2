defmodule BoxwalletWeb.WalletBalanceDisplay do
  use Phoenix.Component
  use Number
  import BoxwalletWeb.CoreComponents

  attr :balance, :float, required: true
  attr :unconfirmed_balance, :float, default: 0.0
  attr :immature_balance, :float, default: 0.0
  attr :hide_balance, :boolean, required: true
  attr :color, :string, default: "text-gray-500"

  def balance_display(assigns) do
    unconfirmed = assigns.unconfirmed_balance || 0.0
    immature = assigns.immature_balance || 0.0
    has_unconfirmed = unconfirmed > 0 or immature > 0
    display_balance = assigns.balance + unconfirmed + immature

    assigns =
      assigns
      |> Phoenix.Component.assign(:has_unconfirmed, has_unconfirmed)
      |> Phoenix.Component.assign(:display_balance, display_balance)

    ~H"""
    <div class="relative flex items-baseline gap-1">
      <span class={["text-lg font-normal", @color]}>
        {if @has_unconfirmed, do: "Unconfirmed Balance:", else: "Balance:"}
      </span>

      <small class="badge text-3xl font-mono border-0">
        {if @hide_balance, do: "●●●●●●", else: Number.Delimit.number_to_delimited(@display_balance, precision: 2)}
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
