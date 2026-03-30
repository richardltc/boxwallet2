defmodule BoxwalletWeb.CoinSidebar do
  use Phoenix.Component
  import BoxwalletWeb.CoreComponents

  attr :color, :string, default: "text-gray-500"
  attr :active_tab, :atom, default: :home

  def coin_sidebar(assigns) do
    ~H"""
    <aside class="flex flex-col items-center gap-1 bg-base-200 rounded-2xl py-4 px-4 shadow-md">
      <button
        class={"btn btn-ghost btn-square flex flex-col items-center h-auto py-2 gap-0.5 transition-all duration-200 hover:scale-110 hover:opacity-100" <> if(@active_tab == :home, do: "", else: " opacity-40")}
        title="Home"
        phx-click="switch_tab"
        phx-value-tab="home"
      >
        <.icon name="hero-home" class={"w-6 h-6 " <> @color} />
        <span class="text-[10px] font-semibold uppercase tracking-wide">Home</span>
      </button>
      <button
        class={"btn btn-ghost btn-square flex flex-col items-center h-auto py-2 gap-0.5 transition-all duration-200 hover:scale-110 hover:opacity-100" <> if(@active_tab == :transactions, do: "", else: " opacity-40")}
        title="Transactions"
        phx-click="switch_tab"
        phx-value-tab="transactions"
      >
        <.icon name="hero-list-bullet" class={"w-6 h-6 " <> @color} />
        <span class="text-[10px] font-semibold uppercase tracking-wide">Trans</span>
      </button>
      <button
        class={"btn btn-ghost btn-square flex flex-col items-center h-auto py-2 gap-0.5 transition-all duration-200 hover:scale-110 hover:opacity-100" <> if(@active_tab == :receive, do: "", else: " opacity-40")}
        title="Receive"
        phx-click="switch_tab"
        phx-value-tab="receive"
      >
        <.icon name="hero-arrow-down-tray" class={"w-6 h-6 " <> @color} />
        <span class="text-[10px] font-semibold uppercase tracking-wide">Receive</span>
      </button>
      <button
        class={"btn btn-ghost btn-square flex flex-col items-center h-auto py-2 gap-0.5 transition-all duration-200 hover:scale-110 hover:opacity-100" <> if(@active_tab == :send, do: "", else: " opacity-40")}
        title="Send"
        phx-click="switch_tab"
        phx-value-tab="send"
      >
        <.icon name="hero-paper-airplane" class={"w-6 h-6 " <> @color} />
        <span class="text-[10px] font-semibold uppercase tracking-wide">Send</span>
      </button>
      <button
        class={"btn btn-ghost btn-square flex flex-col items-center h-auto py-2 gap-0.5 transition-all duration-200 hover:scale-110 hover:opacity-100" <> if(@active_tab == :settings, do: "", else: " opacity-40")}
        title="Settings"
        phx-click="switch_tab"
        phx-value-tab="settings"
      >
        <.icon name="hero-cog-6-tooth" class={"w-6 h-6 " <> @color} />
        <span class="text-[10px] font-semibold uppercase tracking-wide">Settings</span>
      </button>
    </aside>
    """
  end
end
