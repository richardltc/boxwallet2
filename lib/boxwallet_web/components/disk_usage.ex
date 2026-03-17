defmodule BoxwalletWeb.DiskUsage do
  use Phoenix.Component

  @doc """
  Renders a radial progress indicator for disk space usage, styled to match
  the Headers/Blocks sync indicators.

  `used_bytes` and `total_bytes` are raw byte counts (integers or floats).
  100% means the disk is full.

  ## Examples

      <.disk_usage used_bytes={42_000_000_000} total_bytes={100_000_000_000} color="text-rddred" />
  """
  attr :used_bytes, :any, required: true
  attr :total_bytes, :any, required: true
  attr :color, :string, default: "text-gray-500"

  def disk_usage(assigns) do
    used = if is_number(assigns.used_bytes), do: assigns.used_bytes, else: 0
    total = if is_number(assigns.total_bytes), do: assigns.total_bytes, else: 0
    pct = if total > 0, do: Float.round(used / total * 100, 2), else: 0

    formatted =
      cond do
        total <= 0 -> "---"
        pct >= 100 -> "Full"
        pct == 0 -> "0%"
        true -> (:io_lib.format("~.1f", [pct]) |> to_string()) <> "%"
      end

    assigns = assign(assigns, pct: pct, formatted: formatted)

    ~H"""
    <div class="flex flex-col items-center">
      <h3 class="text-sm font-semibold uppercase tracking-wider text-gray-500 mb-4">
        Disk Used
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
