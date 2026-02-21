defmodule BoxwalletWeb.PromptModal do
  @moduledoc """
  A reusable prompt modal component using a LiveView-idiomatic conditional render.

  Show/hide is controlled by the `show` assign. When `show` is true the modal
  is mounted into the DOM — which means `phx-mounted` focus works naturally.

  Pass `show_confirm={true}` with `on_change`, `passwords_match`,
  `answer_value`, and `confirm_value` to enable a confirmation input
  with server-side validation on every keystroke.
  """

  use Phoenix.Component
  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :show_confirm, :boolean, default: false
  attr :passwords_match, :boolean, default: true
  attr :answer_value, :string, default: ""
  attr :confirm_value, :string, default: ""
  attr :question, :string, required: true
  attr :icon, :string, default: nil
  attr :on_confirm, :string, required: true
  attr :on_cancel, :string, required: true
  attr :on_change, :string, default: nil
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

          <form phx-submit={@on_confirm} phx-change={@on_change} id={"#{@id}-form"}>
            <input
              type={@input_type}
              name="answer"
              value={@answer_value}
              placeholder={@placeholder}
              autocomplete="off"
              required
              phx-mounted={JS.focus()}
              class="input input-bordered w-full"
            />

            <%= if @show_confirm do %>
              <input
                type={@input_type}
                name="answer_confirm"
                value={@confirm_value}
                placeholder="Confirm password..."
                autocomplete="off"
                required
                class="input input-bordered w-full mt-3"
              />
              <p :if={not @passwords_match and (@answer_value != "" or @confirm_value != "")} class="text-error text-sm mt-2">
                Passwords do not match.
              </p>
            <% end %>
          </form>

          <div class="modal-action">
            <button type="button" class="btn" phx-click={JS.push(@on_cancel)}>
              {@cancel_label}
            </button>
            <button
              type="submit"
              form={"#{@id}-form"}
              class="btn btn-primary"
              disabled={@show_confirm and (not @passwords_match or (@answer_value == "" and @confirm_value == ""))}
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
