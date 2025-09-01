defmodule BoxwalletWeb.PageController do
  use BoxwalletWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
