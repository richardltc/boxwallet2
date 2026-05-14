defmodule BoxWallet.Coins.Zano.GetBalance do
  @moduledoc """
  Represents a simplewallet RPC getbalance response.
  See: https://docs.zano.org/docs/build/rpc-api/wallet-rpc-api/getbalance

  All amounts are in atomic units (10^12 per ZANO).
  """

  defmodule Result do
    defstruct balance: 0,
              unlocked_balance: 0,
              awaiting_in: 0,
              awaiting_out: 0

    @type t :: %__MODULE__{
            balance: integer(),
            unlocked_balance: integer(),
            awaiting_in: integer(),
            awaiting_out: integer()
          }
  end

  defstruct [:result, :error, :id]

  @type t :: %__MODULE__{
          result: Result.t() | nil,
          error: any(),
          id: any()
        }

  def from_json(json_string) do
    with {:ok, decoded} <- Jason.decode(json_string),
         {:ok, response} <- parse(decoded) do
      {:ok, response}
    end
  end

  defp parse(%{"result" => result, "id" => id} = decoded) do
    {:ok,
     %__MODULE__{
       result: parse_result(result),
       error: Map.get(decoded, "error"),
       id: id
     }}
  end

  defp parse(_), do: {:error, :unexpected_response_shape}

  defp parse_result(nil), do: nil

  defp parse_result(result) do
    %Result{
      balance: result["balance"] || 0,
      unlocked_balance: result["unlocked_balance"] || 0,
      awaiting_in: result["awaiting_in"] || 0,
      awaiting_out: result["awaiting_out"] || 0
    }
  end
end
