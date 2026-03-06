defmodule BoxWallet.Coins.ReddCoin.GetNewAddress do
  @moduledoc """
  Represents a wallet RPC getnewaddress response
  """

  @enforce_keys [:result, :error, :id]

  defstruct [
    :result,
    :error,
    :id
  ]

  @type t :: %__MODULE__{
          result: String.t() | nil,
          error: any(),
          id: String.t()
        }

  @doc """
  Decodes JSON string into a GetNewAddress struct
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
       result: result,
       error: error,
       id: id
     }}
  end
end
