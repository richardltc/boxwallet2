defmodule BoxwalletWeb.CoreWalletBalance do
  use Phoenix.Component

  @doc """
  Renders a balance card with coin, balance, and description.

  ## Examples

              <.wallet_balance_card
                coin="DIVI"
                balance={@balance}
                description="Total"
              />
  """
  attr :coin, :string, required: true, doc: "COIN_ABBREV"
  attr :balance, :float, required: true, doc: "Total coins"
  attr :description, :string, default: nil, doc: "Optional description text"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def wallet_balance_card(assigns) do
    ~H"""
    <div class={"stats shadow #{@class}"}>
      <div class="stat">
        <div class="stat-title">{@coin}</div>
        <div class="stat-value">{Number.Delimit.number_to_delimited(@balance, precision: 8)}</div>
        <div :if={@description} class="stat-desc">{@description}</div>
      </div>
    </div>
    """
  end
end
