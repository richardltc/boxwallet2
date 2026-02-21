defmodule BoxwalletWeb.PromptModal do
  @moduledoc """
  A reusable prompt modal component using a LiveView-idiomatic conditional render.

  Show/hide is controlled by the `show` assign. When `show` is true the modal
  is mounted into the DOM — which means `autofocus` works naturally and no
  JavaScript `showModal()` calls are needed.

  ## Example

      <.prompt_modal
        id="wallet-password"
        icon="hero-lock-closed"
        question="Enter your wallet password:"
        input_type="password"
        placeholder="Enter password..."
        show={@show_prompt}
        on_confirm="prompt_submitted"
        on_cancel="prompt_cancelled"
      />

      def handle_event("prompt_submitted", %{"answer" => password}, socket) do
        {:noreply, assign(socket, show_prompt: false)}
      end

      def handle_event("prompt_cancelled", _params, socket) do
        {:noreply, assign(socket, show_prompt: false)}
      end
  """

  use Phoenix.Component
  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :question, :string, required: true
  attr :icon, :string, default: nil
  attr :on_confirm, :string, required: true
  attr :on_cancel, :string, required: true
  attr :input_type, :string, default: "text"
  attr :placeholder, :string, default: ""
  attr :confirm_label, :string, default: "Confirm"
  attr :cancel_label, :string, default: "Cancel"

  def prompt_modal(assigns) do
    ~H"""
    <%= if @show do %>
      <div id={@id} class="modal modal-open">
        <div class="modal-box">
          <div class="flex items-center gap-3 mb-4">
            <span :if={@icon} class={[@icon, "h-7 w-7 text-base-content/60 shrink-0"]} />
            <h3 class="font-bold text-lg">{@question}</h3>
          </div>

          <form phx-submit={@on_confirm} id={"#{@id}-form"}>
            <input
              type={@input_type}
              name="answer"
              value=""
              placeholder={@placeholder}
              autocomplete="off"
              required
              phx-mounted={JS.focus()}
              class="input input-bordered w-full"
            />
            <button type="submit" id={"#{@id}-hidden-submit"} class="hidden" />
          </form>

          <div class="modal-action">
            <button type="button" class="btn" phx-click={JS.push(@on_cancel)}>
              {@cancel_label}
            </button>
            <button
              type="button"
              class="btn btn-primary"
              onclick={"document.getElementById('#{@id}-hidden-submit').click()"}
            >
              {@confirm_label}
            </button>
          </div>
        </div>

        <div class="modal-backdrop" phx-click={JS.push(@on_cancel)}></div>
      </div>
    <% end %>
    """
  end
end
