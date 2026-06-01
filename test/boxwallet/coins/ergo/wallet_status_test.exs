defmodule BoxWallet.Coins.Ergo.WalletStatusTest do
  use ExUnit.Case, async: true

  alias BoxWallet.Coins.Ergo.WalletStatus

  describe "from_json/1 with a decoded map" do
    test "an uninitialised wallet" do
      assert {:ok, status} =
               WalletStatus.from_json(%{
                 "isInitialized" => false,
                 "isUnlocked" => false,
                 "changeAddress" => "",
                 "walletHeight" => 0,
                 "error" => ""
               })

      assert status.is_initialized == false
      assert status.is_unlocked == false
      assert status.change_address == ""
      assert status.wallet_height == 0
    end

    test "an initialised, locked wallet" do
      assert {:ok, status} =
               WalletStatus.from_json(%{
                 "isInitialized" => true,
                 "isUnlocked" => false,
                 "changeAddress" => "9f...abc",
                 "walletHeight" => 1_234_500
               })

      assert status.is_initialized == true
      assert status.is_unlocked == false
      assert status.change_address == "9f...abc"
      assert status.wallet_height == 1_234_500
    end

    test "an initialised, unlocked wallet" do
      assert {:ok, status} =
               WalletStatus.from_json(%{
                 "isInitialized" => true,
                 "isUnlocked" => true,
                 "changeAddress" => "9f...abc"
               })

      assert status.is_initialized == true
      assert status.is_unlocked == true
    end
  end

  describe "from_json/1 with a raw JSON string" do
    test "decodes then parses" do
      json = Jason.encode!(%{"isInitialized" => true, "isUnlocked" => true})
      assert {:ok, status} = WalletStatus.from_json(json)
      assert status.is_initialized == true
      assert status.is_unlocked == true
    end

    test "returns an error tuple for invalid JSON" do
      assert {:error, _reason} = WalletStatus.from_json("nope")
    end
  end

  test "from_json/1 returns :unexpected_response for unexpected input" do
    assert {:error, :unexpected_response} = WalletStatus.from_json([])
  end
end
