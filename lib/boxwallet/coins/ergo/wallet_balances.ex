defmodule BoxWallet.Coins.Ergo.WalletBalances do
  @moduledoc """
  Represents the response from Ergo's `GET /wallet/balances` endpoint.

  `balance` is in nanoERG (1 ERG = 1_000_000_000 nanoERG). Use `balance_erg/1`
  for a display-friendly ERG float. `assets` is the list of native tokens held.

  `from_json/1` accepts either a raw JSON string or an already-decoded map
  (Req decodes JSON response bodies to maps automatically).
  """
  @nano_per_erg 1_000_000_000

  @derive Jason.Encoder
  defstruct [
    :height,
    :balance,
    assets: []
  ]

  @type t :: %__MODULE__{
          height: integer() | nil,
          balance: integer() | nil,
          assets: list(map())
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
       height: decoded["height"],
       balance: decoded["balance"],
       assets: decoded["assets"] || []
     }}
  end

  def from_json(_), do: {:error, :unexpected_response}

  @doc """
  Converts a nanoERG balance to ERG as a float. Returns 0.0 when balance is nil.
  """
  def balance_erg(%__MODULE__{balance: nil}), do: 0.0
  def balance_erg(%__MODULE__{balance: balance}), do: balance / @nano_per_erg
end
