defmodule BoxwalletWeb.PromptModal do
  @moduledoc """
  A reusable prompt modal component using DaisyUI's `<dialog>` element.

  Uses the same pattern as the existing install confirmation dialog —
  open with `onclick="element.showModal()"`, close with `method="dialog"`.

  No hooks, no extra JS setup needed.

  ## Example — Wallet Decrypt

      # In template — the button to open:
      <button
        class="btn btn-primary"
        onclick="document.getElementById('wallet-password').showModal()"
      >
        Decrypt Wallet
      </button>

      # The modal itself:
      <.prompt_modal
        id="wallet-password"
        icon="hero-lock-closed"
        question="Enter your wallet password to decrypt:"
        input_type="password"
        placeholder="Enter password..."
        confirm_label="Decrypt"
        on_confirm="prompt_submitted"
        on_cancel="prompt_cancelled"
      />

      # Handle the answer:
      def handle_event("prompt_submitted", %{"answer" => password}, socket) do
        IO.puts("Got password: " <> password)
        {:noreply, socket}
      end

      def handle_event("prompt_cancelled", _params, socket) do
        {:noreply, socket}
      end
  """

  use Phoenix.Component
  alias Phoenix.LiveView.JS

  attr :id, :string, required: true, doc: "Unique DOM id for the modal dialog"
  attr :question, :string, required: true, doc: "The prompt text shown to the user"

  attr :icon, :string,
    default: nil,
    doc: "HeroIcon class, e.g. \"hero-lock-closed\", \"hero-shield-check\""

  attr :on_confirm, :string,
    required: true,
    doc: "Event name on submit (payload: %{\"answer\" => value})"

  attr :on_cancel, :string, required: true, doc: "Event name on cancel"

  attr :input_type, :string,
    default: "text",
    doc: "HTML input type (\"text\", \"password\", etc.)"

  attr :placeholder, :string, default: "", doc: "Input placeholder text"
  attr :confirm_label, :string, default: "Confirm", doc: "Submit button label"
  attr :cancel_label, :string, default: "Cancel", doc: "Cancel button label"

  def prompt_modal(assigns) do
    ~H"""
    <dialog id={@id} class="modal">
      <div class="modal-box">
        <%!-- Icon + Question --%>
        <div class="flex items-center gap-3 mb-4">
          <span
            :if={@icon}
            class={[@icon, "h-7 w-7 text-base-content/60 shrink-0"]}
          />
          <h3 class="font-bold text-lg">{@question}</h3>
        </div>

        <%!-- Input (hidden form just to hold the phx-submit) --%>
        <form phx-submit={@on_confirm} id={"#{@id}-form"}>
          <input
            type={@input_type}
            name="answer"
            value=""
            placeholder={@placeholder}
            autocomplete="off"
            required
            class="input input-bordered w-full"
          />

          <%!-- Hidden submit button — the visible one below triggers this form --%>
          <button type="submit" id={"#{@id}-hidden-submit"} class="hidden" />
        </form>

        <%!-- Buttons row — outside the phx-submit form so Cancel won't trigger validation --%>
        <div class="modal-action">
          <form method="dialog">
            <button type="submit" class="btn" phx-click={JS.push(@on_cancel)}>
              {@cancel_label}
            </button>
          </form>
          <button
            type="button"
            class="btn btn-primary"
            onclick={"document.getElementById('#{@id}-hidden-submit').click()"}
            phx-disable-with="..."
          >
            {@confirm_label}
          </button>
        </div>
      </div>

      <%!-- Click backdrop to close --%>
      <form method="dialog" class="modal-backdrop">
        <button>close</button>
      </form>
    </dialog>
    """
  end
end
