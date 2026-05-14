defmodule BoxWallet.Coins.Zano.GetRecentTxs do
  @moduledoc """
  Represents a simplewallet RPC `get_recent_txs_and_info` response, normalised
  into the same shape the `BoxwalletWeb.CoinTransactions` component consumes
  (i.e. `address`, `amount`, `category`, `confirmations`, `blocktime`, `txid`).

  Zano amounts come in atomic units (10^12 per ZANO); we convert to floats here.
  """

  defmodule Transaction do
    @enforce_keys [:address, :category, :amount, :confirmations, :txid]
    defstruct [
      :address,
      :amount,
      :category,
      :confirmations,
      :txid,
      :blocktime,
      :height,
      :fee
    ]

    @type t :: %__MODULE__{
            address: String.t(),
            amount: float(),
            category: String.t(),
            confirmations: integer(),
            txid: String.t(),
            blocktime: integer() | nil,
            height: integer() | nil,
            fee: float() | nil
          }
  end

  defstruct [:result, :error, :id]

  @type t :: %__MODULE__{
          result: list(Transaction.t()),
          error: any(),
          id: any()
        }

  @atomic_per_zano 1_000_000_000_000

  def from_json(json_string, current_height \\ 0) do
    with {:ok, decoded} <- Jason.decode(json_string),
         {:ok, response} <- parse(decoded, current_height) do
      {:ok, response}
    end
  end

  defp parse(%{"result" => nil} = decoded, _current_height) do
    {:ok,
     %__MODULE__{
       result: [],
       error: Map.get(decoded, "error"),
       id: Map.get(decoded, "id")
     }}
  end

  defp parse(%{"result" => result} = decoded, current_height) do
    txs =
      (result["transfers"] || result["txs"] || [])
      |> Enum.map(&parse_tx(&1, current_height))
      |> Enum.reject(&is_nil/1)

    {:ok,
     %__MODULE__{
       result: txs,
       error: Map.get(decoded, "error"),
       id: Map.get(decoded, "id")
     }}
  end

  defp parse(_, _), do: {:error, :unexpected_response_shape}

  defp parse_tx(nil, _), do: nil

  defp parse_tx(tx, current_height) do
    height = tx["height"]
    confirmations = if height && current_height > 0, do: max(0, current_height - height), else: 0
    is_income = tx["is_income"] == true
    amount_atomic = tx["amount"] || 0
    amount = amount_atomic / @atomic_per_zano

    %Transaction{
      txid: tx["tx_hash"] || tx["txid"] || "",
      address: List.first(tx["remote_addresses"] || []) || "",
      amount: if(is_income, do: amount, else: -amount),
      category: if(is_income, do: "receive", else: "send"),
      confirmations: confirmations,
      blocktime: tx["timestamp"],
      height: height,
      fee: (tx["fee"] || 0) / @atomic_per_zano
    }
  end
end
