defmodule BoxWallet.Coins.ReddCoin.GetBlockchainInfo do
  @moduledoc """
  Represents a wallet RPC getblockchaininfo response.
  """

  defmodule Result do
    @enforce_keys [
      :chain,
      :blocks,
      :headers,
      :bestblockhash,
      :difficulty,
      :chainwork
    ]

    defstruct [
      :chain,
      :blocks,
      :headers,
      :bestblockhash,
      :difficulty,
      :moneysupply,
      :mediantime,
      :verificationprogress,
      :initialblockdownload,
      :chainwork,
      :size_on_disk,
      :pruned,
      :softforks,
      :warnings
    ]

    @type t :: %__MODULE__{
            chain: String.t(),
            blocks: integer(),
            headers: integer(),
            bestblockhash: String.t(),
            difficulty: float(),
            moneysupply: float() | nil,
            mediantime: integer() | nil,
            verificationprogress: float() | nil,
            initialblockdownload: boolean() | nil,
            chainwork: String.t(),
            size_on_disk: integer() | nil,
            pruned: boolean() | nil,
            softforks: map() | nil,
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
      chain: result["chain"],
      blocks: result["blocks"],
      headers: result["headers"],
      bestblockhash: result["bestblockhash"],
      difficulty: result["difficulty"],
      moneysupply: result["moneysupply"],
      mediantime: result["mediantime"],
      verificationprogress: result["verificationprogress"],
      initialblockdownload: result["initialblockdownload"],
      chainwork: result["chainwork"],
      size_on_disk: result["size_on_disk"],
      pruned: result["pruned"],
      softforks: result["softforks"],
      warnings: result["warnings"]
    }
  end
end
