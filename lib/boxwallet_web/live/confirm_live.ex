defmodule BoxwalletWeb.ConfirmLive do
  use BoxwalletWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, show_confirmation: false, action: nil)}
  end

  def handle_event("request_delete", _, socket) do
    {:noreply, assign(socket, show_confirmation: true, action: "delete")}
  end

  def handle_event("confirm", _, socket) do
    case socket.assigns.action do
      "delete" ->
        # Perform the delete action
        {:noreply, assign(socket, show_confirmation: false, action: nil)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("cancel", _, socket) do
    {:noreply, assign(socket, show_confirmation: false, action: nil)}
  end
end
