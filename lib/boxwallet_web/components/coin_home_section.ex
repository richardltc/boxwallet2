defmodule BoxwalletWeb.CoinHomeSection do
  use Phoenix.Component
  import BoxwalletWeb.SyncProgress

  attr :coin_name, :string, required: true
  attr :coin_description, :string, required: true
  attr :headers_synced, :integer, required: true
  attr :blocks_synced, :integer, required: true
  attr :block_height, :integer, required: true
  attr :color, :string, required: true
  attr :coin_files_exist, :boolean, required: true
  attr :downloading, :boolean, required: true
  attr :download_complete, :boolean, required: true
  attr :download_error, :any, default: nil
  attr :coin_daemon_started, :boolean, required: true
  attr :coin_daemon_stopped, :boolean, required: true
  attr :wallet_encryption_status, :atom, required: true
  attr :on_download, :string, required: true

  def coin_home_section(assigns) do
    ~H"""
    <!-- Description section -->
    <div class="text-center border-t border-gray-100 pt-6">
      <p class="text-gray-400 text-lg leading-relaxed max-w-2xl mx-auto">
        {@coin_description}
      </p>
      <.sync_stats
        headers_synced={@headers_synced}
        blocks_synced={@blocks_synced}
        block_height={@block_height}
        color={@color}
      />
    </div>

    <!-- Action buttons -->
    <div class="card-actions justify-center mt-8">
      <button
        class="btn btn-boxwalletgreen px-8 disabled:opacity-40"
        onclick="install_modal.showModal()"
        disabled={@downloading or @coin_files_exist}
        title={"Install #{@coin_name} core files"}
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="1.5"
          stroke="currentColor"
          class="size-6"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5M16.5 12 12 16.5m0 0L7.5 12m4.5 4.5V3"
          />
        </svg>
        Install
      </button>
      <!-- DaisyUI Modal Dialog -->
      <dialog id="install_modal" class="modal">
        <div class="modal-box">
          <h3 class="font-bold text-lg">Confirm Installation</h3>
          <p class="py-4">Are you sure you want to install the {@coin_name} core files?</p>
          <div class="modal-action">
            <!-- Yes button -->
            <form method="dialog">
              <button
                class="btn btn-success mr-2"
                phx-click={@on_download}
                onclick="install_modal.close()"
                disabled={@downloading}
              >
                Yes
              </button>
            </form>
            <!-- No button -->
            <form method="dialog">
              <button class="btn btn-error">No</button>
            </form>
          </div>
        </div>
      </dialog>

      <button
        class="btn btn-outline btn-boxwalletgreen px-8 disabled:opacity-40"
        phx-click="start_coin_daemon"
        disabled={!@coin_files_exist or !@coin_daemon_stopped}
        title={"Start #{@coin_name} Daemon"}
      >
        <span class="hero-play h-6 w-6" /> Start
      </button>

      <button
        class="btn btn-outline btn-boxwalletgreen px-8 disabled:opacity-40"
        phx-click="stop_coin_daemon"
        disabled={!@coin_daemon_started}
        title={"Stop #{@coin_name} Daemon"}
      >
        <span class="hero-stop h-6 w-6" /> Stop
      </button>

      <div class="dropdown dropdown-bottom">
        <button
          class="btn btn-outline btn-boxwalletgreen px-8 disabled:opacity-40"
          disabled={!@coin_daemon_started}
          phx-click={
            case @wallet_encryption_status do
              :wes_unencrypted -> "show_encrypt_prompt"
              :wes_unlocked -> "lock_wallet"
              :wes_unlocked_for_staking -> "lock_wallet"
              _ -> nil
            end
          }
        >
          <span class={
            case @wallet_encryption_status do
              :wes_unlocked -> "hero-lock-closed h-6 w-6"
              :wes_unlocked_for_staking -> "hero-lock-closed h-6 w-6"
              _ -> "hero-lock-open h-6 w-6"
            end
          } /> {case @wallet_encryption_status do
            :wes_unencrypted -> "Encrypt"
            :wes_unlocked -> "Lock"
            :wes_unlocked_for_staking -> "Lock"
            _ -> "Unlock"
          end}
        </button>
        <%= if @wallet_encryption_status == :wes_locked do %>
          <ul
            tabindex="-1"
            class="dropdown-content menu bg-base-100 rounded-box z-1 w-52 p-2 shadow-sm"
          >
            <li>
              <a phx-click="show_unlock_prompt">
                <span class="hero-lock-open h-5 w-5 inline-block" /> Unlock
              </a>
            </li>
            <li>
              <a phx-click="show_unlock_staking_prompt">
                <span class="hero-bolt h-5 w-5 inline-block" />Unlock for staking
              </a>
            </li>
          </ul>
        <% end %>
      </div>
    </div>
    """
  end
end
