defmodule BoxWallet.Coins.Zano.GetAddress do
  @moduledoc """
  Represents a simplewallet RPC getaddress response.
  """

  defmodule Result do
    defstruct [:address]
    @type t :: %__MODULE__{address: String.t() | nil}
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

  defp parse_result(result) when is_binary(result) do
    %Result{address: result}
  end

  defp parse_result(result) do
    %Result{address: result["address"]}
  end
end
