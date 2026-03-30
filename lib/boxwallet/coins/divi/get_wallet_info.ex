defmodule BoxWallet.Coins.Divi.GetWalletInfo do
  @moduledoc """
  Represents a wallet RPC getwalletinfo response
  """

  defmodule Result do
    defstruct active_wallet: nil,
              walletversion: nil,
              balance: 0.0,
              unconfirmed_balance: 0.0,
              immature_balance: 0.0,
              spendable_balance: 0.0,
              vaulted_balance: 0.0,
              txcount: 0,
              keypoolsize: 0,
              unlocked_until: nil,
              encryption_status: "unencrypted"

    @type t :: %__MODULE__{
            active_wallet: String.t() | nil,
            walletversion: integer() | nil,
            balance: float(),
            unconfirmed_balance: float(),
            immature_balance: float(),
            spendable_balance: float(),
            vaulted_balance: float(),
            txcount: integer(),
            keypoolsize: integer(),
            unlocked_until: integer() | nil,
            encryption_status: String.t()
          }
  end

  @enforce_keys [:result, :error, :id]

  defstruct [
    :result,
    :error,
    :id
  ]

  @type t :: %__MODULE__{
          result: Result.t(),
          error: any(),
          id: String.t()
        }

  @doc """
  Decodes JSON string into a GetInfo struct
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
       result: parse_result(result),
       error: error,
       id: id
     }}
  end

  defp parse_result(result) do
    %Result{
      active_wallet: result["active_wallet"],
      walletversion: result["walletversion"],
      balance: result["balance"] || 0.0,
      unconfirmed_balance: result["unconfirmed_balance"] || 0.0,
      immature_balance: result["immature_balance"] || 0.0,
      spendable_balance: result["spendable_balance"] || 0.0,
      vaulted_balance: result["vaulted_balance"] || 0.0,
      txcount: result["txcount"] || 0,
      keypoolsize: result["keypoolsize"] || 0,
      unlocked_until: result["unlocked_until"],
      encryption_status: result["encryption_status"] || "unencrypted"
    }
  end
end
