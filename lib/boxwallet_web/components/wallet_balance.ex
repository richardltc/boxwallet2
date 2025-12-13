defmodule BoxwalletWeb.CoreWalletBalance do
  use Phoenix.Component

  @doc """
  Renders a balance card with coin, amount, and description.

  ## Examples

      <.wallet_balance_card
        coin="DIVI"
        amount="89,400"
        description="DIVI total"
      />

      <.wallet_balance_card
        coin="Active Users"
        amount={@amount}
        description="DIVI total"
      />
  """
  attr :coin, :string, required: true, doc: "COIN_ABBREV"
  attr :amount, :string, required: true, doc: "Total coins"
  attr :description, :string, default: nil, doc: "Optional description text"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def wallet_balance_card(assigns) do
    ~H"""
    <div class={"stats shadow #{@class}"}>
      <div class="stat">
        <div class="stat-title">{@coin}</div>
        <div class="stat-value">{@amount}</div>
        <div :if={@description} class="stat-desc">{@description}</div>
      </div>
    </div>
    """
  end
end
