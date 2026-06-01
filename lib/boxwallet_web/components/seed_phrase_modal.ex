defmodule BoxwalletWeb.SeedPhraseModal do
  @moduledoc """
  Reusable wallet create/restore modal driven by BIP39-style seed phrases.

  This is a presentational component: the parent LiveView owns all state
  (`mode`, the generated `mnemonic`, any `error`) and handles the emitted
  events. It is built standalone — rather than baked into one coin's view —
  so the same flow can back wallet creation/restore for every coin. Ergo is
  the first consumer.

  Flow (driven by the `mode` assign):

    * `:menu`          — choose "Create new wallet" or "Restore from seed"
    * `:create`        — enter + confirm a spending password (`on_create`)
    * `:show_mnemonic` — display the generated `mnemonic` for backup
                         (`on_mnemonic_done`)
    * `:restore`       — paste an existing mnemonic + password (`on_restore`)
  """
  use Phoenix.Component
  import BoxwalletWeb.CoreComponents
  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :mode, :atom, default: :menu
  attr :mnemonic, :string, default: nil
  attr :error, :string, default: nil
  attr :color, :string, default: "text-primary"
  # Event names emitted to the parent LiveView.
  attr :on_choose, :string, required: true
  attr :on_create, :string, required: true
  attr :on_restore, :string, required: true
  attr :on_mnemonic_done, :string, required: true
  attr :on_cancel, :string, required: true

  def wallet_setup_modal(assigns) do
    assigns = assign(assigns, :words, mnemonic_words(assigns.mnemonic))

    ~H"""
    <%= if @show do %>
      <div id={@id} class="modal modal-open">
        <div class="modal-box max-w-lg">
          <div class="flex items-center gap-3 mb-4">
            <span class={["hero-wallet h-7 w-7 shrink-0", @color]} />
            <h3 class="font-bold text-lg">{title(@mode)}</h3>
          </div>

          <div :if={@error} role="alert" class="alert alert-error mb-4">
            <span>{@error}</span>
          </div>

          <%= case @mode do %>
            <% :menu -> %>
              <p class="text-sm text-base-content/70 mb-4">
                Create a brand new wallet, or restore an existing one from its
                15-word recovery phrase.
              </p>
              <div class="flex flex-col gap-3">
                <button
                  type="button"
                  class="btn btn-outline btn-boxwalletgreen"
                  phx-click={JS.push(@on_choose, value: %{mode: "create"})}
                >
                  <.icon name="hero-plus-circle" class="h-5 w-5" /> Create new wallet
                </button>
                <button
                  type="button"
                  class="btn btn-outline"
                  phx-click={JS.push(@on_choose, value: %{mode: "restore"})}
                >
                  <.icon name="hero-arrow-uturn-left" class="h-5 w-5" /> Restore from seed phrase
                </button>
              </div>

            <% :create -> %>
              <form phx-submit={@on_create} id={"#{@id}-create-form"} class="space-y-3">
                <p class="text-sm text-base-content/70">
                  Choose a spending password. You'll need it to unlock the wallet
                  and to send funds.
                </p>
                <input
                  type="password"
                  name="pass"
                  placeholder="Spending password..."
                  autocomplete="off"
                  required
                  phx-mounted={JS.focus()}
                  class="input input-bordered w-full"
                />
                <input
                  type="password"
                  name="pass_confirm"
                  placeholder="Confirm password..."
                  autocomplete="off"
                  required
                  class="input input-bordered w-full"
                />
              </form>

            <% :show_mnemonic -> %>
              <div role="alert" class="alert alert-warning mb-4">
                <.icon name="hero-exclamation-triangle" class="h-6 w-6 shrink-0" />
                <span>
                  Write these 15 words down and keep them safe. Anyone with them
                  can spend your funds, and we cannot recover them for you.
                </span>
              </div>
              <div class="grid grid-cols-3 gap-2">
                <div
                  :for={{word, idx} <- @words}
                  class="badge badge-lg badge-outline w-full justify-start font-mono"
                >
                  <span class="opacity-50 mr-1">{idx}.</span>
                  {word}
                </div>
              </div>

            <% :restore -> %>
              <form phx-submit={@on_restore} id={"#{@id}-restore-form"} class="space-y-3">
                <p class="text-sm text-base-content/70">
                  Enter your 15-word recovery phrase (words separated by spaces)
                  and choose a spending password.
                </p>
                <textarea
                  name="mnemonic"
                  rows="3"
                  placeholder="word1 word2 word3 ..."
                  required
                  phx-mounted={JS.focus()}
                  class="textarea textarea-bordered w-full font-mono"
                ></textarea>
                <input
                  type="password"
                  name="pass"
                  placeholder="Spending password..."
                  autocomplete="off"
                  required
                  class="input input-bordered w-full"
                />
              </form>
          <% end %>

          <div class="modal-action">
            <%= case @mode do %>
              <% :menu -> %>
                <button type="button" class="btn" phx-click={JS.push(@on_cancel)}>Cancel</button>

              <% :create -> %>
                <button
                  type="button"
                  class="btn"
                  phx-click={JS.push(@on_choose, value: %{mode: "menu"})}
                >
                  Back
                </button>
                <button type="submit" form={"#{@id}-create-form"} class="btn btn-primary">
                  Create wallet
                </button>

              <% :show_mnemonic -> %>
                <button type="button" class="btn btn-primary" phx-click={JS.push(@on_mnemonic_done)}>
                  I've backed it up
                </button>

              <% :restore -> %>
                <button
                  type="button"
                  class="btn"
                  phx-click={JS.push(@on_choose, value: %{mode: "menu"})}
                >
                  Back
                </button>
                <button type="submit" form={"#{@id}-restore-form"} class="btn btn-primary">
                  Restore wallet
                </button>
            <% end %>
          </div>
        </div>

        <div class="modal-backdrop" phx-click={JS.push(@on_cancel)}></div>
      </div>
    <% end %>
    """
  end

  defp title(:menu), do: "Set up your wallet"
  defp title(:create), do: "Create a new wallet"
  defp title(:show_mnemonic), do: "Back up your recovery phrase"
  defp title(:restore), do: "Restore your wallet"
  defp title(_), do: "Set up your wallet"

  defp mnemonic_words(nil), do: []

  defp mnemonic_words(mnemonic) when is_binary(mnemonic) do
    mnemonic
    |> String.split(~r/\s+/, trim: true)
    |> Enum.with_index(1)
    |> Enum.map(fn {word, idx} -> {word, idx} end)
  end
end
