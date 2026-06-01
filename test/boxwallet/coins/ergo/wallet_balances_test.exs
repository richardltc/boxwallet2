defmodule BoxWallet.Coins.Ergo.WalletBalancesTest do
  use ExUnit.Case, async: true

  alias BoxWallet.Coins.Ergo.WalletBalances

  describe "from_json/1" do
    test "parses height, balance (nanoERG) and assets" do
      assert {:ok, balances} =
               WalletBalances.from_json(%{
                 "height" => 1_234_567,
                 "balance" => 2_500_000_000,
                 "assets" => [%{"tokenId" => "abc", "amount" => 5}]
               })

      assert balances.height == 1_234_567
      assert balances.balance == 2_500_000_000
      assert [%{"tokenId" => "abc"}] = balances.assets
    end

    test "defaults assets to an empty list when absent" do
      assert {:ok, balances} =
               WalletBalances.from_json(%{"height" => 1, "balance" => 0})

      assert balances.assets == []
    end

    test "decodes a raw JSON string" do
      json = Jason.encode!(%{"height" => 1, "balance" => 1_000_000_000})
      assert {:ok, balances} = WalletBalances.from_json(json)
      assert balances.balance == 1_000_000_000
    end

    test "returns :unexpected_response for unexpected input" do
      assert {:error, :unexpected_response} = WalletBalances.from_json(42)
    end
  end

  describe "balance_erg/1" do
    test "divides nanoERG by 1e9" do
      assert {:ok, balances} = WalletBalances.from_json(%{"balance" => 2_500_000_000})
      assert WalletBalances.balance_erg(balances) == 2.5
    end

    test "returns 0.0 when balance is nil" do
      assert {:ok, balances} = WalletBalances.from_json(%{"height" => 1})
      assert balances.balance == nil
      assert WalletBalances.balance_erg(balances) == 0.0
    end
  end
end
