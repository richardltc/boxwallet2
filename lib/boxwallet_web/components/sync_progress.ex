defmodule BoxwalletWeb.SyncProgress do
  use Phoenix.Component

  @doc """
  Renders a pair of radial progress indicators for Headers and Blocks sync status.

  ## Examples

      <.sync_stats
        headers_synced={@headers_synced}
        blocks_synced={@blocks_synced}
        block_height={@block_height}
        color="text-divired"
      />
  """
  attr :headers_synced, :float, required: true
  attr :blocks_synced, :float, required: true
  attr :block_height, :float, required: true
  attr :color, :string, default: "text-gray-500"

  def sync_stats(assigns) do
    ~H"""
    <div class="stats shadow mt-3 flex flex-row gap-8 p-6 justify-center items-center">
      <.radial_progress label="Headers" synced={@headers_synced} total={@block_height} color={@color} />
      <.radial_progress label="Blocks" synced={@blocks_synced} total={@block_height} color={@color} />
    </div>
    """
  end

  @doc """
  Renders a single radial progress indicator.

  ## Examples

      <.radial_progress label="Headers" synced={1000.0} total={2000.0} color="text-divired" />
  """
  attr :label, :string, required: true
  attr :synced, :float, required: true
  attr :total, :float, required: true
  attr :color, :string, default: "text-gray-500"
  attr :pct_override, :float, default: nil

  def radial_progress(assigns) do
    synced = if is_number(assigns.synced), do: assigns.synced, else: 0
    total = if is_number(assigns.total), do: assigns.total, else: 0

    pct =
      cond do
        is_number(assigns.pct_override) -> Float.round(assigns.pct_override, 2)
        total > 0 -> Float.round(synced / total * 100, 2)
        true -> 0
      end

    formatted =
      cond do
        assigns.total <= 0 -> "---"
        pct == 0 -> "0"
        pct >= 100 -> "Synced"
        true -> (:io_lib.format("~.2f", [pct]) |> to_string()) <> "%"
      end

    assigns = assign(assigns, pct: pct, formatted: formatted)

    ~H"""
    <div class="flex flex-col items-center">
      <h3 class="text-sm font-semibold uppercase tracking-wider text-gray-500 mb-4">
        {@label}
      </h3>
      <div
        class={["radial-progress", @color]}
        style={"--value:#{@pct}; --size:6rem;"}
        aria-valuenow={@pct}
        role="progressbar"
      >
        {@formatted}
      </div>
    </div>
    """
  end
end
