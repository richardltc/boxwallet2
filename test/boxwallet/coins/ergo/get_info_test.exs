defmodule BoxWallet.Coins.Ergo.GetInfoTest do
  use ExUnit.Case, async: true

  alias BoxWallet.Coins.Ergo.GetInfo

  # A representative subset of the flat object Ergo's `GET /info` returns.
  # NOTE: shape coded to docs, not yet confirmed against a live 6.0.2 node.
  defp sample_map do
    %{
      "fullHeight" => 1_234_567,
      "headersHeight" => 1_234_567,
      "maxPeerHeight" => 1_234_570,
      "peersCount" => 30,
      "difficulty" => 1_199_990_374_400,
      "isMining" => false,
      "appVersion" => "6.0.2",
      "network" => "mainnet",
      "unconfirmedCount" => 12
    }
  end

  describe "from_json/1 with a decoded map" do
    test "maps every camelCase field onto the struct" do
      assert {:ok, info} = GetInfo.from_json(sample_map())

      assert info.full_height == 1_234_567
      assert info.headers_height == 1_234_567
      assert info.max_peer_height == 1_234_570
      assert info.peers_count == 30
      assert info.difficulty == 1_199_990_374_400
      assert info.is_mining == false
      assert info.app_version == "6.0.2"
      assert info.network == "mainnet"
      assert info.unconfirmed_count == 12
    end

    test "leaves heights nil before the node has started syncing" do
      assert {:ok, info} =
               GetInfo.from_json(%{"appVersion" => "6.0.2", "peersCount" => 0})

      assert info.full_height == nil
      assert info.headers_height == nil
      assert info.app_version == "6.0.2"
      assert info.peers_count == 0
    end
  end

  describe "from_json/1 with a raw JSON string" do
    test "decodes then parses" do
      json = Jason.encode!(sample_map())
      assert {:ok, info} = GetInfo.from_json(json)
      assert info.full_height == 1_234_567
      assert info.network == "mainnet"
    end

    test "returns an error tuple for invalid JSON" do
      assert {:error, _reason} = GetInfo.from_json("{not json")
    end
  end

  test "from_json/1 returns :unexpected_response for unexpected input" do
    assert {:error, :unexpected_response} = GetInfo.from_json(123)
    assert {:error, :unexpected_response} = GetInfo.from_json(nil)
  end
end
