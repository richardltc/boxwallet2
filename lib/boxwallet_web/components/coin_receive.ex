defmodule BoxwalletWeb.CoinReceive do
  use Phoenix.Component
  import BoxwalletWeb.CoreComponents
  alias Phoenix.LiveView.JS

  attr :color, :string, required: true
  attr :coin_daemon_started, :boolean, default: false
  attr :receive_address, :string, default: ""
  attr :receive_coming_soon, :boolean, default: false

  def coin_receive(assigns) do
    qr_svg =
      if assigns.receive_address != "" do
        assigns.receive_address
        |> EQRCode.encode()
        |> EQRCode.svg(width: 256)
      else
        ""
      end

    assigns = assign(assigns, :qr_svg, qr_svg)

    ~H"""
    <div class="border-t border-gray-100 pt-6">
      <p class={"text-lg font-semibold text-center " <> @color}>Receive</p>

      <%= if @receive_coming_soon do %>
        <div class="flex justify-center mt-4">
          <button class="btn btn-outline btn-boxwalletgreen px-8 cursor-not-allowed" disabled title="Coming soon">
            <.icon name="hero-arrow-down-tray" class="w-6 h-6" /> Receive
            <span class="badge badge-sm ml-1">Coming soon</span>
          </button>
        </div>
      <% else %>
        <%= if @receive_address != "" do %>
          <div class="flex flex-col items-center mt-4">
            <div class="bg-white p-4 rounded-xl mb-4">
              {Phoenix.HTML.raw(@qr_svg)}
            </div>

            <div class="w-full max-w-md">
              <label class="label">
                <span class="label-text font-semibold">Address</span>
              </label>
              <div class="flex gap-2">
                <input
                  type="text"
                  value={@receive_address}
                  readonly
                  class="input input-bordered w-full font-mono text-sm"
                  id="receive-address-input"
                />
                <button
                  type="button"
                  class="btn btn-square btn-outline"
                  title="Copy to clipboard"
                  phx-click={JS.dispatch("phx:copy", to: "#receive-address-input")}
                >
                  <span class="hero-clipboard-document w-5 h-5" />
                </button>
              </div>
            </div>

            <button
              class="btn btn-outline btn-boxwalletgreen px-8 mt-6"
              phx-click="new_receive_address"
              disabled={!@coin_daemon_started}
              title="Generate a new receive address"
            >
              <.icon name="hero-plus" class="w-5 h-5" /> New Address
            </button>
          </div>
        <% else %>
          <div class="flex flex-col items-center mt-8">
            <%= if @coin_daemon_started do %>
              <span class={"loading loading-spinner loading-lg " <> @color}></span>
              <p class="text-gray-400 mt-4">Fetching address...</p>
            <% else %>
              <p class="text-gray-400">Daemon not running</p>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
