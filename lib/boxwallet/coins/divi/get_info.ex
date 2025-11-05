defmodule BoxWallet.Coins.Divi.GetInfo do
  @moduledoc """
  Represents a wallet RPC getinfo response
  """

  defmodule Result do
    @enforce_keys [
      :version,
      :protocolversion,
      :walletversion,
      :balance,
      :blocks,
      :timeoffset,
      :connections,
      :proxy,
      :difficulty,
      :testnet,
      :moneysupply,
      :relayfee,
      :staking_status,
      :errors
    ]

    defstruct [
      :version,
      :protocolversion,
      :walletversion,
      :balance,
      :blocks,
      :timeoffset,
      :connections,
      :proxy,
      :difficulty,
      :testnet,
      :moneysupply,
      :relayfee,
      :staking_status,
      :errors
    ]

    @type t :: %__MODULE__{
            version: String.t(),
            protocolversion: integer(),
            walletversion: integer(),
            balance: float(),
            blocks: integer(),
            timeoffset: integer(),
            connections: integer(),
            proxy: String.t(),
            difficulty: float(),
            testnet: boolean(),
            moneysupply: float(),
            relayfee: float(),
            staking_status: String.t(),
            errors: String.t()
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
      version: result["version"],
      protocolversion: result["protocolversion"],
      walletversion: result["walletversion"],
      balance: result["balance"],
      blocks: result["blocks"],
      timeoffset: result["timeoffset"],
      connections: result["connections"],
      proxy: result["proxy"],
      difficulty: result["difficulty"],
      testnet: result["testnet"],
      moneysupply: result["moneysupply"],
      relayfee: result["relayfee"],
      staking_status: result["staking status"],
      errors: result["errors"]
    }
  end
end
