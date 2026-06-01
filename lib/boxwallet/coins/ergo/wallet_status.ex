defmodule BoxWallet.Coins.Ergo.WalletStatus do
  @moduledoc """
  Represents the response from Ergo's `GET /wallet/status` endpoint.

  Ergo has no "usable unencrypted" wallet state like the Bitcoin-Core coins.
  Instead the wallet is either not initialised (`is_initialized == false`),
  or initialised and then locked/unlocked. The Ergo server maps these to the
  shared wallet-encryption-status atoms:

    * `is_initialized == false` -> `:wes_unencrypted` (prompt create/restore)
    * `is_unlocked == false`    -> `:wes_locked`
    * `is_unlocked == true`     -> `:wes_unlocked`

  `from_json/1` accepts either a raw JSON string or an already-decoded map
  (Req decodes JSON response bodies to maps automatically).
  """
  @derive Jason.Encoder
  defstruct [
    :is_initialized,
    :is_unlocked,
    :change_address,
    :wallet_height,
    :error
  ]

  @type t :: %__MODULE__{
          is_initialized: boolean() | nil,
          is_unlocked: boolean() | nil,
          change_address: String.t() | nil,
          wallet_height: integer() | nil,
          error: String.t() | nil
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
       is_initialized: decoded["isInitialized"],
       is_unlocked: decoded["isUnlocked"],
       change_address: decoded["changeAddress"],
       wallet_height: decoded["walletHeight"],
       error: decoded["error"]
     }}
  end

  def from_json(_), do: {:error, :unexpected_response}
end
