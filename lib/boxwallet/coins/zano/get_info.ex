defmodule BoxWallet.Coins.Zano.GetInfo do
  @moduledoc """
  Represents a Zano daemon RPC getinfo response.
  See: https://docs.zano.org/docs/build/rpc-api/daemon-rpc-api/getinfo
  """

  defmodule Result do
    defstruct [
      :height,
      :tx_count,
      :alias_count,
      :alt_blocks_count,
      :last_block_hash,
      :last_block_timestamp,
      :pow_difficulty,
      :pos_difficulty,
      :block_reward,
      :daemon_network_state,
      :incoming_connections_count,
      :outgoing_connections_count,
      :synchronized_connections_count,
      :grey_peerlist_size,
      :white_peerlist_size,
      :tx_pool_size,
      :default_fee,
      :minimum_fee,
      :status,
      :total_coins,
      :max_net_seen_height
    ]

    @type t :: %__MODULE__{
            height: integer(),
            tx_count: integer(),
            alias_count: integer(),
            alt_blocks_count: integer(),
            last_block_hash: String.t(),
            last_block_timestamp: integer(),
            pow_difficulty: String.t(),
            pos_difficulty: String.t(),
            block_reward: integer(),
            daemon_network_state: integer(),
            incoming_connections_count: integer(),
            outgoing_connections_count: integer(),
            synchronized_connections_count: integer(),
            grey_peerlist_size: integer(),
            white_peerlist_size: integer(),
            tx_pool_size: integer(),
            default_fee: integer(),
            minimum_fee: integer(),
            status: String.t(),
            total_coins: String.t(),
            max_net_seen_height: integer()
          }
  end

  defstruct [:result, :error, :id]

  @type t :: %__MODULE__{
          result: Result.t() | nil,
          error: any(),
          id: any()
        }

  @doc """
  Decodes a JSON string into a GetInfo struct.
  """
  def from_json(json_string) do
    with {:ok, decoded} <- Jason.decode(json_string),
         {:ok, response} <- parse(decoded) do
      {:ok, response}
    end
  end

  defp parse(%{"result" => result, "id" => id} = decoded) do
    {:ok,
     %__MODULE__{
       result: parse_result(result),
       error: Map.get(decoded, "error"),
       id: id
     }}
  end

  defp parse(_), do: {:error, :unexpected_response_shape}

  defp parse_result(nil), do: nil

  defp parse_result(result) do
    %Result{
      height: result["height"],
      tx_count: result["tx_count"],
      alias_count: result["alias_count"],
      alt_blocks_count: result["alt_blocks_count"],
      last_block_hash: result["last_block_hash"],
      last_block_timestamp: result["last_block_timestamp"],
      pow_difficulty: result["pow_difficulty"],
      pos_difficulty: result["pos_difficulty"],
      block_reward: result["block_reward"],
      daemon_network_state: result["daemon_network_state"],
      incoming_connections_count: result["incoming_connections_count"],
      outgoing_connections_count: result["outgoing_connections_count"],
      synchronized_connections_count: result["synchronized_connections_count"],
      grey_peerlist_size: result["grey_peerlist_size"],
      white_peerlist_size: result["white_peerlist_size"],
      tx_pool_size: result["tx_pool_size"],
      default_fee: result["default_fee"],
      minimum_fee: result["minimum_fee"],
      status: result["status"],
      total_coins: result["total_coins"],
      max_net_seen_height: result["max_net_seen_height"]
    }
  end
end
