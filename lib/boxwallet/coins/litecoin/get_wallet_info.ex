defmodule Boxwallet.Coins.Litecoin.GetWalletInfo do
  @moduledoc """
  Represents a Litecoin RPC getwalletinfo response.
  """

  defmodule Result do
    @enforce_keys [
      :walletname,
      :walletversion,
      :balance
    ]

    defstruct [
      :walletname,
      :walletversion,
      :format,
      :balance,
      :unconfirmed_balance,
      :immature_balance,
      :txcount,
      :keypoololdest,
      :keypoolsize,
      :hdseedid,
      :keypoolsize_hd_internal,
      :paytxfee,
      :private_keys_enabled,
      :avoid_reuse,
      :scanning,
      :descriptors,
      :unlocked_until
    ]

    @type t :: %__MODULE__{
            walletname: String.t(),
            walletversion: integer(),
            format: String.t() | nil,
            balance: float(),
            unconfirmed_balance: float() | nil,
            immature_balance: float() | nil,
            txcount: integer() | nil,
            keypoololdest: integer() | nil,
            keypoolsize: integer() | nil,
            hdseedid: String.t() | nil,
            keypoolsize_hd_internal: integer() | nil,
            paytxfee: float() | nil,
            private_keys_enabled: boolean() | nil,
            avoid_reuse: boolean() | nil,
            scanning: boolean() | map() | nil,
            descriptors: boolean() | nil,
            unlocked_until: integer() | nil
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
      walletname: result["walletname"],
      walletversion: result["walletversion"],
      format: result["format"],
      balance: result["balance"],
      unconfirmed_balance: result["unconfirmed_balance"],
      immature_balance: result["immature_balance"],
      txcount: result["txcount"],
      keypoololdest: result["keypoololdest"],
      keypoolsize: result["keypoolsize"],
      hdseedid: result["hdseedid"],
      keypoolsize_hd_internal: result["keypoolsize_hd_internal"],
      paytxfee: result["paytxfee"],
      private_keys_enabled: result["private_keys_enabled"],
      avoid_reuse: result["avoid_reuse"],
      scanning: result["scanning"],
      descriptors: result["descriptors"],
      unlocked_until: result["unlocked_until"]
    }
  end
end
