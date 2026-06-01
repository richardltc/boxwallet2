defmodule BoxWallet.Coins.Ergo.GetInfo do
  @moduledoc """
  Represents the response from Ergo's `GET /info` endpoint.

  Unlike the Bitcoin-Core style coins, Ergo's REST API returns a flat JSON
  object (no JSON-RPC `result` envelope), so we parse the top-level map. A
  single `/info` call covers blocks, headers, peer count and sync progress.

  `from_json/1` accepts either a raw JSON string or an already-decoded map
  (Req decodes JSON response bodies to maps automatically).

  Note that `full_height` / `headers_height` can be `nil` before the node has
  started syncing.
  """
  @derive Jason.Encoder
  defstruct [
    :full_height,
    :headers_height,
    :max_peer_height,
    :peers_count,
    :difficulty,
    :is_mining,
    :app_version,
    :network,
    :unconfirmed_count
  ]

  @type t :: %__MODULE__{
          full_height: integer() | nil,
          headers_height: integer() | nil,
          max_peer_height: integer() | nil,
          peers_count: integer() | nil,
          difficulty: integer() | nil,
          is_mining: boolean() | nil,
          app_version: String.t() | nil,
          network: String.t() | nil,
          unconfirmed_count: integer() | nil
        }

  def from_json(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, decoded} -> from_json(decoded)
      {:error, reason} -> {:error, reason}
    end
  end

  def from_json(decoded) when is_map(decoded) do
    {:ok,
     %__MODULE__{
       full_height: decoded["fullHeight"],
       headers_height: decoded["headersHeight"],
       max_peer_height: decoded["maxPeerHeight"],
       peers_count: decoded["peersCount"],
       difficulty: decoded["difficulty"],
       is_mining: decoded["isMining"],
       app_version: decoded["appVersion"],
       network: decoded["network"],
       unconfirmed_count: decoded["unconfirmedCount"]
     }}
  end

  def from_json(_), do: {:error, :unexpected_response}
end
