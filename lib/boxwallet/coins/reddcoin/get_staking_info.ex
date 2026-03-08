defmodule BoxWallet.Coins.ReddCoin.GetStakingInfo do
  @moduledoc """
  Represents a wallet RPC getstakinginfo response.
  """

  defmodule Result do
    @enforce_keys [
      :enabled,
      :staking
    ]

    defstruct [
      :enabled,
      :staking,
      :chain,
      :blocks,
      :currentblockweight,
      :currentblocktx,
      :difficulty,
      :networkhashps,
      :pooledtx,
      :search_interval,
      :averageweight,
      :totalweight,
      :netstakeweight,
      :expectedtime,
      :warnings
    ]

    @type t :: %__MODULE__{
            enabled: boolean(),
            staking: boolean(),
            chain: String.t() | nil,
            blocks: integer() | nil,
            currentblockweight: integer() | nil,
            currentblocktx: integer() | nil,
            difficulty: float() | nil,
            networkhashps: float() | nil,
            pooledtx: integer() | nil,
            search_interval: integer() | nil,
            averageweight: integer() | nil,
            totalweight: integer() | nil,
            netstakeweight: integer() | nil,
            expectedtime: integer() | nil,
            warnings: String.t() | nil
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
  Decodes JSON string into a GetStakingInfo struct
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
      enabled: result["enabled"],
      staking: result["staking"],
      chain: result["chain"],
      blocks: result["blocks"],
      currentblockweight: result["currentblockweight"],
      currentblocktx: result["currentblocktx"],
      difficulty: result["difficulty"],
      networkhashps: result["networkhashps"],
      pooledtx: result["pooledtx"],
      search_interval: result["search-interval"],
      averageweight: result["averageweight"],
      totalweight: result["totalweight"],
      netstakeweight: result["netstakeweight"],
      expectedtime: result["expectedtime"],
      warnings: result["warnings"]
    }
  end
end
