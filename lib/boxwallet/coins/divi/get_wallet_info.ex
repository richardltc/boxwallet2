defmodule BoxWallet.Coins.Divi.GetWalletInfo do
  @moduledoc """
  Represents a wallet RPC getwalletinfo response
  """

  defmodule Result do
    @enforce_keys [
      :active_wallet,
      :walletversion,
      :balance,
      :unconfirmed_balance,
      :immature_balance,
      :spendable_balance,
      :vaulted_balance,
      :txcount,
      :keypoolsize,
      :unlocked_until,
      :encryption_status
    ]

    defstruct [
      :active_wallet,
      :walletversion,
      :balance,
      :unconfirmed_balance,
      :immature_balance,
      :spendable_balance,
      :vaulted_balance,
      :txcount,
      :keypoolsize,
      :unlocked_until,
      :encryption_status
    ]

    @type t :: %__MODULE__{
            active_wallet: String.t(),
            walletversion: integer(),
            balance: float(),
            unconfirmed_balance: float(),
            immature_balance: float(),
            spendable_balance: float(),
            vaulted_balance: float(),
            txcount: integer(),
            keypoolsize: boolean(),
            unlocked_until: integer(),
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
      balance: result["balance"],
      unconfirmed_balance: result["unconfirmed_balance"],
      immature_balance: result["immature_balance"],
      spendable_balance: result["spendable_balance"],
      vaulted_balance: result["vaulted_balance"],
      txcount: result["txcount"],
      keypoolsize: result["keypoolsize"],
      unlocked_until: result["unlocked_until"],
      encryption_status: result["encryption_status"]
    }
  end
end
