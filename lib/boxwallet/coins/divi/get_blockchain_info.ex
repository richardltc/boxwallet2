defmodule BoxWallet.Coins.Divi.GetBlockchainInfo do
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
      :chainwork
    ]

    @type t :: %__MODULE__{
            chain: String.t(),
            blocks: integer(),
            headers: integer(),
            bestblockhash: String.t(),
            difficulty: float(),
            chainwork: String.t()
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
      chainwork: result["chainwork"]
    }
  end
end
