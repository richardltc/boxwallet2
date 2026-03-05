defmodule BoxWallet.Coins.ReddCoin.GetPeerInfo do
  @moduledoc """
  Represents a wallet RPC getpeerinfo response.
  """

  defmodule Peer do
    @enforce_keys [
      :id,
      :addr,
      :addrbind,
      :addrlocal,
      :network,
      :services,
      :servicesnames,
      :relaytxes,
      :lastsend,
      :lastrecv,
      :last_transaction,
      :last_block,
      :bytessent,
      :bytesrecv,
      :conntime,
      :timeoffset,
      :pingtime,
      :minping,
      :version,
      :subver,
      :inbound,
      :bip152_hb_to,
      :bip152_hb_from,
      :startingheight,
      :synced_headers,
      :synced_blocks,
      :inflight,
      :addr_processed,
      :addr_rate_limited,
      :permissions,
      :minfeefilter,
      :bytessent_per_msg,
      :bytesrecv_per_msg,
      :connection_type
    ]
    defstruct [
      :id,
      :addr,
      :addrbind,
      :addrlocal,
      :network,
      :services,
      :servicesnames,
      :relaytxes,
      :lastsend,
      :lastrecv,
      :last_transaction,
      :last_block,
      :bytessent,
      :bytesrecv,
      :conntime,
      :timeoffset,
      :pingtime,
      :minping,
      :version,
      :subver,
      :inbound,
      :bip152_hb_to,
      :bip152_hb_from,
      :startingheight,
      :synced_headers,
      :synced_blocks,
      :inflight,
      :addr_processed,
      :addr_rate_limited,
      :permissions,
      :minfeefilter,
      :bytessent_per_msg,
      :bytesrecv_per_msg,
      :connection_type
    ]

    @type t :: %__MODULE__{
            id: integer(),
            addr: String.t(),
            addrbind: String.t(),
            addrlocal: String.t(),
            network: String.t(),
            services: String.t(),
            servicesnames: [String.t()],
            relaytxes: boolean(),
            lastsend: integer(),
            lastrecv: integer(),
            last_transaction: integer(),
            last_block: integer(),
            bytessent: integer(),
            bytesrecv: integer(),
            conntime: integer(),
            timeoffset: integer(),
            pingtime: float(),
            minping: float(),
            version: integer(),
            subver: String.t(),
            inbound: boolean(),
            bip152_hb_to: boolean(),
            bip152_hb_from: boolean(),
            startingheight: integer(),
            synced_headers: integer(),
            synced_blocks: integer(),
            inflight: list(),
            addr_processed: integer(),
            addr_rate_limited: integer(),
            permissions: list(),
            minfeefilter: float(),
            bytessent_per_msg: map(),
            bytesrecv_per_msg: map(),
            connection_type: String.t()
          }
  end

  @enforce_keys [:result, :error, :id]
  defstruct [
    :result,
    :error,
    :id
  ]

  @type t :: %__MODULE__{
          result: [Peer.t()],
          error: any(),
          id: String.t()
        }

  @doc """
  Decodes JSON string into a GetPeerInfo struct.
  """
  def from_json(json_string) do
    with {:ok, decoded} <- Jason.decode(json_string),
         {:ok, response} <- parse(decoded) do
      {:ok, response}
    end
  end

  defp parse(%{"result" => result, "error" => error, "id" => id}) do
    {:ok,
     %__MODULE__{
       result: Enum.map(result || [], &parse_peer/1),
       error: error,
       id: id
     }}
  end

  defp parse_peer(peer) do
    %Peer{
      id: peer["id"],
      addr: peer["addr"],
      addrbind: peer["addrbind"],
      addrlocal: peer["addrlocal"],
      network: peer["network"],
      services: peer["services"],
      servicesnames: peer["servicesnames"] || [],
      relaytxes: peer["relaytxes"],
      lastsend: peer["lastsend"],
      lastrecv: peer["lastrecv"],
      last_transaction: peer["last_transaction"],
      last_block: peer["last_block"],
      bytessent: peer["bytessent"],
      bytesrecv: peer["bytesrecv"],
      conntime: peer["conntime"],
      timeoffset: peer["timeoffset"],
      pingtime: peer["pingtime"],
      minping: peer["minping"],
      version: peer["version"],
      subver: peer["subver"],
      inbound: peer["inbound"],
      bip152_hb_to: peer["bip152_hb_to"],
      bip152_hb_from: peer["bip152_hb_from"],
      startingheight: peer["startingheight"],
      synced_headers: peer["synced_headers"],
      synced_blocks: peer["synced_blocks"],
      inflight: peer["inflight"] || [],
      addr_processed: peer["addr_processed"],
      addr_rate_limited: peer["addr_rate_limited"],
      permissions: peer["permissions"] || [],
      minfeefilter: peer["minfeefilter"],
      bytessent_per_msg: peer["bytessent_per_msg"] || %{},
      bytesrecv_per_msg: peer["bytesrecv_per_msg"] || %{},
      connection_type: peer["connection_type"]
    }
  end
end
