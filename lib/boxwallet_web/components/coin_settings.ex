defmodule BoxwalletWeb.CoinSettings do
  use Phoenix.Component
  import BoxwalletWeb.CoreComponents

  attr :coin_name, :string, required: true
  attr :color, :string, required: true
  attr :testnet_enabled, :boolean, required: true

  def coin_settings(assigns) do
    ~H"""
    <div class="border-t border-gray-100 pt-6">
      <h3 class="text-xl font-bold mb-6">
        <.icon name="hero-cog-6-tooth" class={"w-6 h-6 inline-block mr-2 " <> @color} /> Settings
      </h3>

      <div class="flex items-center justify-between p-4 bg-base-100 rounded-xl">
        <div>
          <h4 class="font-semibold text-lg">Test Net</h4>
          <p class="text-sm text-gray-400">
            Enable to connect to the {@coin_name} test network instead of mainnet.
            The daemon will need to be restarted after changing this setting.
          </p>
        </div>
        <input
          type="checkbox"
          class={"toggle toggle-lg " <> toggle_color(@color)}
          checked={@testnet_enabled}
          onclick="testnet_modal.showModal(); this.checked = !this.checked;"
        />
      </div>

      <!-- Confirmation modal -->
      <dialog id="testnet_modal" class="modal">
        <div class="modal-box">
          <h3 class="font-bold text-lg">Confirm Network Change</h3>
          <%= if @testnet_enabled do %>
            <p class="py-4">
              Are you sure you want to switch {@coin_name} to <strong>mainnet</strong>?
              The daemon will be stopped and will need to be restarted.
            </p>
          <% else %>
            <p class="py-4">
              Are you sure you want to switch {@coin_name} to <strong>testnet</strong>?
              The daemon will be stopped and will need to be restarted.
            </p>
          <% end %>
          <div class="modal-action">
            <form method="dialog">
              <button
                class="btn btn-success mr-2"
                phx-click="confirm_toggle_testnet"
                onclick="testnet_modal.close()"
              >
                Yes
              </button>
            </form>
            <form method="dialog">
              <button class="btn btn-error">No</button>
            </form>
          </div>
        </div>
      </dialog>
    </div>
    """
  end

  defp toggle_color("text-divired"), do: "toggle-error"
  defp toggle_color("text-rddred"), do: "toggle-error"
  defp toggle_color(_), do: "toggle-error"
end
