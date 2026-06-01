defmodule BoxWallet.Coins.Ergo.ListTransactionsTest do
  use ExUnit.Case, async: true

  alias BoxWallet.Coins.Ergo.ListTransactions
  alias BoxWallet.Coins.Ergo.ListTransactions.Transaction

  defp sample_tx do
    %{
      "id" => "tx-abc",
      "numConfirmations" => 7,
      "inclusionHeight" => 1_234_500,
      "outputs" => [
        %{"address" => "9fReceiver", "value" => 1_500_000_000},
        %{"address" => "9fChange", "value" => 500_000_000}
      ]
    }
  end

  describe "from_json/1 with a decoded list" do
    test "maps a transaction into the shared component shape" do
      assert {:ok, [%Transaction{} = tx]} = ListTransactions.from_json([sample_tx()])

      assert tx.txid == "tx-abc"
      assert tx.address == "9fReceiver"
      assert tx.category == "receive"
      # GROSS sum of output box values, in ERG (1.5 + 0.5).
      assert tx.amount == 2.0
      assert tx.confirmations == 7
      assert tx.inclusion_height == 1_234_500
      assert tx.blocktime == nil
    end

    test "defaults confirmations to 0 and address to \"\" when missing" do
      assert {:ok, [tx]} = ListTransactions.from_json([%{"id" => "bare"}])

      assert tx.confirmations == 0
      assert tx.address == ""
      assert tx.amount == 0.0
    end

    test "handles an empty list" do
      assert {:ok, []} = ListTransactions.from_json([])
    end
  end

  describe "from_json/1 with a raw JSON string" do
    test "decodes then parses" do
      json = Jason.encode!([sample_tx()])
      assert {:ok, [tx]} = ListTransactions.from_json(json)
      assert tx.txid == "tx-abc"
      assert tx.amount == 2.0
    end

    test "returns an error tuple for invalid JSON" do
      assert {:error, _reason} = ListTransactions.from_json("[broken")
    end
  end

  test "from_json/1 returns :unexpected_response for a non-list map/value" do
    assert {:error, :unexpected_response} = ListTransactions.from_json(%{"id" => "x"})
    assert {:error, :unexpected_response} = ListTransactions.from_json(99)
  end
end
