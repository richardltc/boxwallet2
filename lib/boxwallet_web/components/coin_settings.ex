defmodule BoxwalletWeb.CoinSettings do
  use Phoenix.Component
  import BoxwalletWeb.CoreComponents

  attr :coin_name, :string, required: true
  attr :color, :string, required: true
  attr :testnet_enabled, :boolean, required: true
  attr :coin_files_exist, :boolean, required: true
  attr :downloading, :boolean, required: true
  attr :download_complete, :boolean, required: true
  attr :download_error, :any, default: nil
  attr :on_update, :string, required: true

  def coin_settings(assigns) do
    ~H"""
    <div class="border-t border-gray-100 pt-6">
      <h3 class="text-xl font-bold mb-6">
        <.icon name="hero-cog-6-tooth" class={"w-6 h-6 inline-block mr-2 " <> @color} /> Settings
      </h3>

      <!-- Update section -->
      <div class="flex items-center justify-between p-4 bg-base-100 rounded-xl mb-4">
        <div>
          <h4 class="font-semibold text-lg">Update</h4>
          <p class="text-sm text-gray-400">
            Download and install the latest {@coin_name} core files.
          </p>
        </div>
        <button
          class="btn btn-outline btn-boxwalletgreen px-8 disabled:opacity-40"
          onclick="update_modal.showModal()"
          disabled={@downloading or !@coin_files_exist}
          title={"Update #{@coin_name} core files"}
        >
          <%= if @downloading do %>
            <span class="loading loading-spinner loading-sm"></span>
            Updating...
          <% else %>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="size-5"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182"
              />
            </svg>
            Update
          <% end %>
        </button>
      </div>

      <!-- Update success alert -->
      <%= if @download_complete do %>
        <div role="alert" class="alert alert-success mb-4">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-6 w-6 shrink-0 stroke-current"
            fill="none"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          <span>Update completed successfully!</span>
        </div>
      <% end %>

      <!-- Update error alert -->
      <%= if @download_error do %>
        <div role="alert" class="alert alert-error mb-4">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-6 w-6 shrink-0 stroke-current"
            fill="none"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          <span>{@download_error}</span>
        </div>
      <% end %>

      <!-- Update confirmation modal -->
      <dialog id="update_modal" class="modal">
        <div class="modal-box">
          <h3 class="font-bold text-lg">Confirm Update</h3>
          <p class="py-4">
            Are you sure you want to update the {@coin_name} core files?
            This will download and install the latest version.
          </p>
          <div class="modal-action">
            <form method="dialog">
              <button
                class="btn btn-success mr-2"
                phx-click={@on_update}
                onclick="update_modal.close()"
                disabled={@downloading}
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

      <!-- Test Net section -->
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
