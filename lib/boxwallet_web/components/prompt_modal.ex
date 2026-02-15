defmodule BoxwalletWeb.PromptModal do
  @moduledoc """
  A Phoenix LiveView component that displays a modal prompt dialog.

  ## Usage

      # In your LiveView template:
      <.prompt_modal
        id="wallet-password"
        question="Enter your wallet password to decrypt:"
        icon="lock-closed"
        show={@show_prompt}
        on_submit="prompt_submitted"
        on_cancel="prompt_cancelled"
        input_type="password"
        placeholder="Enter password..."
      />

      # To show the modal, assign `show_prompt: true` in your LiveView:
      def handle_event("decrypt_wallet", _params, socket) do
        {:noreply, assign(socket, show_prompt: true)}
      end

      # Handle the submitted answer:
      def handle_event("prompt_submitted", %{"answer" => answer}, socket) do
        # Use the answer (e.g., decrypt wallet)
        {:noreply, assign(socket, show_prompt: false)}
      end

      def handle_event("prompt_cancelled", _params, socket) do
        {:noreply, assign(socket, show_prompt: false)}
      end
  """

  use Phoenix.Component

  attr :id, :string, required: true, doc: "Unique ID for the modal"
  attr :question, :string, required: true, doc: "The question/prompt to display"

  attr :icon, :string,
    default: nil,
    doc: "HeroIcon name (e.g. \"lock-closed\", \"key\", \"shield-check\")"

  attr :icon_style, :string,
    default: "hero-",
    doc: "Icon class prefix (hero- for outline, hero-solid- for solid)"

  attr :show, :boolean, default: false, doc: "Whether the modal is visible"

  attr :on_submit, :string,
    required: true,
    doc: "Event name fired on submit with %{\"answer\" => value}"

  attr :on_cancel, :string, required: true, doc: "Event name fired on cancel"
  attr :input_type, :string, default: "text", doc: "Input type: \"text\", \"password\", etc."
  attr :placeholder, :string, default: "", doc: "Input placeholder text"
  attr :submit_label, :string, default: "Submit", doc: "Submit button label"
  attr :cancel_label, :string, default: "Cancel", doc: "Cancel button label"

  def prompt_modal(assigns) do
    ~H"""
    <div
      :if={@show}
      id={@id}
      phx-mounted={focus_input(@id)}
      class="relative z-50"
      aria-labelledby={"#{@id}-title"}
      role="dialog"
      aria-modal="true"
    >
      <%!-- Backdrop --%>
      <div class="fixed inset-0 bg-gray-500/75 transition-opacity" aria-hidden="true" />

      <%!-- Modal positioning --%>
      <div class="fixed inset-0 z-50 overflow-y-auto">
        <div class="flex min-h-full items-start justify-end p-4 sm:p-6">
          <%!-- Modal panel (top-right corner) --%>
          <div class="relative w-full max-w-sm transform overflow-hidden rounded-xl bg-white shadow-2xl ring-1 ring-gray-900/5 transition-all">
            <%!-- Header --%>
            <div class="px-6 pt-6 pb-2">
              <div class="flex items-start gap-4">
                <%!-- Icon --%>
                <div
                  :if={@icon}
                  class="flex-shrink-0 flex h-10 w-10 items-center justify-center rounded-full bg-indigo-100"
                >
                  <span class={"#{@icon_style}#{@icon} h-6 w-6 text-indigo-600"} />
                </div>

                <%!-- Question --%>
                <div class="flex-1 min-w-0">
                  <h3 id={"#{@id}-title"} class="text-base font-semibold leading-6 text-gray-900">
                    {@question}
                  </h3>
                </div>

                <%!-- Close button --%>
                <button
                  type="button"
                  phx-click={@on_cancel}
                  class="flex-shrink-0 rounded-md bg-white text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                >
                  <span class="sr-only">Close</span>
                  <span class="hero-x-mark h-5 w-5" />
                </button>
              </div>
            </div>

            <%!-- Form --%>
            <.form
              for={%{}}
              as={:prompt}
              phx-submit={@on_submit}
              phx-key="escape"
              phx-window-keydown={@on_cancel}
              phx-key="Escape"
              class="px-6 pb-6 pt-2"
            >
              <input
                type={@input_type}
                name="answer"
                id={"#{@id}-input"}
                value=""
                placeholder={@placeholder}
                autocomplete="off"
                required
                class="mt-2 block w-full rounded-lg border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm py-2.5 px-3"
              />

              <div class="mt-4 flex justify-end gap-3">
                <button
                  type="button"
                  phx-click={@on_cancel}
                  class="inline-flex justify-center rounded-lg px-4 py-2 text-sm font-semibold text-gray-700 bg-white ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                >
                  {@cancel_label}
                </button>
                <button
                  type="submit"
                  class="inline-flex justify-center rounded-lg px-4 py-2 text-sm font-semibold text-white bg-indigo-600 hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                >
                  {@submit_label}
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Uses the JS commands module to focus the input on mount — no custom JS needed.
  defp focus_input(id) do
    Phoenix.LiveView.JS.focus(to: "##{id}-input")
  end
end
