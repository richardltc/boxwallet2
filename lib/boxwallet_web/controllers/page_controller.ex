defmodule BoxwalletWeb.PageController do
  use BoxwalletWeb, :controller

  def home(conn, _params) do
    Boxwallet.Coins.Divi.Server.pause_polling()
    Boxwallet.Coins.ReddCoin.Server.pause_polling()
    Boxwallet.Coins.Litecoin.Server.pause_polling()
    Boxwallet.Coins.Zano.Server.pause_polling()
    render(conn, :home)
  end
end
