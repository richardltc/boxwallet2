defmodule BoxwalletWeb.CoreWalletToolbar do
  use Phoenix.Component
  import BoxwalletWeb.CoreComponents

  @doc """
  Renders a horizontal row of exactly six hero icons with hints, colors, and states.

  ## Examples

      <.hero_icons_row icons={[
        %{name: "hero-home", hint: "Home", color: "text-blue-500", state: :enabled},
        %{name: "hero-user", hint: "Profile", color: "text-green-500", state: :enabled},
        %{name: "hero-cog-6-tooth", hint: "Settings", color: "text-purple-500", state: :flashing},
        %{name: "hero-bell", hint: "Alerts", color: "text-red-500", state: :disabled},
        %{name: "hero-envelope", hint: "Messages", color: "text-yellow-500", state: :enabled},
        %{name: "hero-star", hint: "Featured", color: "text-orange-500", state: :enabled}
      ]} />
  """
  attr :icons, :list,
    required: true,
    doc:
      "List of exactly 6 icon maps with :name, :hint, :color, and :state (:enabled, :disabled, or :flashing)"

  attr :class, :string, default: "flex gap-4 items-center"
  attr :icon_class, :string, default: "h-8 w-8"

  attr :hint_class, :string,
    default:
      "absolute bottom-full mb-2 bg-gray-900 text-white text-xs rounded px-2 py-1 whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none"

  def hero_icons_row(assigns) do
    if length(assigns.icons) != 6 do
      raise ArgumentError, "hero_icons_row requires exactly 6 icons, got #{length(assigns.icons)}"
    end

    ~H"""
    <style>
      @keyframes flash {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.3; }
      }
      .flashing {
        animation: flash 2s ease-in-out infinite;
      }
    </style>
    <div class={@class}>
      <%= for icon <- @icons do %>
        <div class="relative group">
          <.icon
            name={icon.name}
            class={[
              @icon_class,
              icon.color,
              state_class(icon.state)
            ]}
          />
          <%= if Map.get(icon, :hint) do %>
            <span class={@hint_class}>
              <%= icon.hint %>
            </span>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp state_class(:disabled), do: "opacity-30 cursor-not-allowed"
  defp state_class(:flashing), do: "flashing cursor-pointer"
  defp state_class(:enabled), do: "cursor-pointer"
  defp state_class(_), do: "cursor-pointer"
end
