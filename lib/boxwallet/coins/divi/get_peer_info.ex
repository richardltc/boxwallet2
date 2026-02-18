defmodule BoxWallet.Coins.Divi.GetPeerInfo do
  @moduledoc """
  Represents a wallet RPC getpeerinfo response.
  """

  defmodule Peer do
    @enforce_keys [
      :id,
      :addr,
      :addrlocal,
      :services,
      :lastsend,
      :lastrecv,
      :bytessent,
      :bytesrecv,
      :conntime,
      :pingtime,
      :version,
      :subver,
      :inbound,
      :startingheight,
      :banscore,
      :synced_headers,
      :synced_blocks,
      :inflight,
      :whitelisted
    ]
    defstruct [
      :id,
      :addr,
      :addrlocal,
      :services,
      :lastsend,
      :lastrecv,
      :bytessent,
      :bytesrecv,
      :conntime,
      :pingtime,
      :version,
      :subver,
      :inbound,
      :startingheight,
      :banscore,
      :synced_headers,
      :synced_blocks,
      :inflight,
      :whitelisted
    ]

    @type t :: %__MODULE__{
            id: integer(),
            addr: String.t(),
            addrlocal: String.t(),
            services: String.t(),
            lastsend: integer(),
            lastrecv: integer(),
            bytessent: integer(),
            bytesrecv: integer(),
            conntime: integer(),
            pingtime: float(),
            version: integer(),
            subver: String.t(),
            inbound: boolean(),
            startingheight: integer(),
            banscore: integer(),
            synced_headers: integer(),
            synced_blocks: integer(),
            inflight: list(),
            whitelisted: boolean()
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
  Decodes JSON string into a GetPeerInfo struct
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
       result: Enum.map(result, &parse_peer/1),
       error: error,
       id: id
     }}
  end

  defp parse_peer(peer) do
    %Peer{
      id: peer["id"],
      addr: peer["addr"],
      addrlocal: peer["addrlocal"],
      services: peer["services"],
      lastsend: peer["lastsend"],
      lastrecv: peer["lastrecv"],
      bytessent: peer["bytessent"],
      bytesrecv: peer["bytesrecv"],
      conntime: peer["conntime"],
      pingtime: peer["pingtime"],
      version: peer["version"],
      subver: peer["subver"],
      inbound: peer["inbound"],
      startingheight: peer["startingheight"],
      banscore: peer["banscore"],
      synced_headers: peer["synced_headers"],
      synced_blocks: peer["synced_blocks"],
      inflight: peer["inflight"],
      whitelisted: peer["whitelisted"]
    }
  end
end
