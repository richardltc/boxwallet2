defmodule BoxwalletWeb.CoinSidebar do
  use Phoenix.Component
  import BoxwalletWeb.CoreComponents

  attr :color, :string, default: "text-gray-500"

  def coin_sidebar(assigns) do
    ~H"""
    <aside class="flex flex-col items-center gap-1 bg-base-200 rounded-2xl py-4 px-2 shadow-md">
      <button class="btn btn-ghost btn-square flex flex-col items-center h-auto py-2 gap-0.5" title="Home">
        <.icon name="hero-home" class={"w-6 h-6 " <> @color} />
        <span class="text-[10px] font-semibold uppercase tracking-wide">Home</span>
      </button>
      <button class="btn btn-ghost btn-square flex flex-col items-center h-auto py-2 gap-0.5" title="Transactions">
        <.icon name="hero-banknotes" class={"w-6 h-6 " <> @color} />
        <span class="text-[10px] font-semibold uppercase tracking-wide">Trans</span>
      </button>
    </aside>
    """
  end
end
