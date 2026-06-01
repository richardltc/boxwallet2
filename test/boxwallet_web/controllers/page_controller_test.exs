defmodule BoxwalletWeb.PageControllerTest do
  use BoxwalletWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)
    assert body =~ "multi-coin wallet"
    # The Ergo coin card links to /ergo.
    assert body =~ ~s(href="/ergo")
    assert body =~ "Ergo"
  end
end
