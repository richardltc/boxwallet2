defmodule BoxwalletWeb.CoinTransactions do
  use Phoenix.Component

  attr :color, :string, required: true

  def coin_transactions(assigns) do
    ~H"""
    <div class="text-center border-t border-gray-100 pt-6">
      <p class={"text-lg font-semibold " <> @color}>Transactions</p>
      <p class="text-gray-400 mt-2">Coming soon</p>
    </div>
    """
  end
end
