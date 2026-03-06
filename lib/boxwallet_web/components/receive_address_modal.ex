defmodule BoxwalletWeb.ReceiveAddressModal do
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :address, :string, default: ""
  attr :on_close, :string, required: true
  attr :color, :string, default: "text-gray-500"

  def receive_address_modal(assigns) do
    qr_svg =
      if assigns.address != "" do
        assigns.address
        |> EQRCode.encode()
        |> EQRCode.svg(width: 256)
      else
        ""
      end

    assigns = assign(assigns, :qr_svg, qr_svg)

    ~H"""
    <%= if @show do %>
      <div id={@id} class="modal modal-open">
        <div class="modal-box flex flex-col items-center">
          <h3 class={"font-bold text-lg mb-4 " <> @color}>Receive Address</h3>

          <div class="bg-white p-4 rounded-xl mb-4">
            {Phoenix.HTML.raw(@qr_svg)}
          </div>

          <div class="w-full">
            <label class="label">
              <span class="label-text font-semibold">Address</span>
            </label>
            <div class="flex gap-2">
              <input
                type="text"
                value={@address}
                readonly
                class="input input-bordered w-full font-mono text-sm"
                id={"#{@id}-address"}
              />
              <button
                type="button"
                class="btn btn-square btn-outline"
                title="Copy to clipboard"
                phx-click={
                  JS.dispatch("phx:copy", to: "##{@id}-address")
                }
              >
                <span class="hero-clipboard-document w-5 h-5" />
              </button>
            </div>
          </div>

          <div class="modal-action">
            <button type="button" class="btn" phx-click={JS.push(@on_close)}>
              Close
            </button>
          </div>
        </div>

        <div class="modal-backdrop" phx-click={JS.push(@on_close)}></div>
      </div>
    <% end %>
    """
  end
end
