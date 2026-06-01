defmodule Boxwallet.Coins.ErgoTest do
  use ExUnit.Case, async: true

  alias Boxwallet.Coins.Ergo
  alias BoxWallet.Coins.Auth

  describe "constants" do
    test "coin metadata" do
      assert Ergo.coin_name_abbrev() == "ERG"
      assert Ergo.core_version() == "6.0.2"
      assert Ergo.jar_file() == "ergo-6.0.2.jar"
    end
  end

  describe "get_auth_values/0" do
    test "returns the fixed local api_key as the password on port 9053" do
      assert {:ok, %Auth{rpc_port: "9053", rpc_user: "", rpc_password: password}} =
               Ergo.get_auth_values()

      assert password == "BoxWalletErgoLocalApiKey"
    end
  end

  describe "validate_address/1" do
    test "accepts a plausible mainnet P2PK address (starts with 9, 40-60 chars)" do
      addr = "9" <> String.duplicate("a", 50)
      assert String.length(addr) == 51
      assert Ergo.validate_address(addr)
    end

    test "rejects addresses that do not start with 9" do
      refute Ergo.validate_address("8" <> String.duplicate("a", 50))
    end

    test "rejects addresses that are too short" do
      refute Ergo.validate_address("9abc")
    end

    test "rejects addresses that are too long" do
      refute Ergo.validate_address("9" <> String.duplicate("a", 60))
    end

    test "rejects non-binary input" do
      refute Ergo.validate_address(nil)
      refute Ergo.validate_address(123)
    end
  end

  describe "java_install_instructions/0" do
    test "returns OS-appropriate, non-empty guidance mentioning Java" do
      instructions = Ergo.java_install_instructions()
      assert is_binary(instructions)
      assert instructions =~ "Java"
      assert instructions =~ "https://adoptium.net/"
    end
  end
end
