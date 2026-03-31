defmodule BoxWallet.Coins.ReddCoin.ListTransactions do
  @moduledoc """
  Represents a wallet RPC listtransactions response.
  """

  defmodule Transaction do
    @enforce_keys [
      :address,
      :category,
      :amount,
      :confirmations,
      :txid
    ]

    defstruct [
      :address,
      :category,
      :amount,
      :label,
      :vout,
      :confirmations,
      :blockhash,
      :blockheight,
      :blockindex,
      :blocktime,
      :txid,
      :walletconflicts,
      :time,
      :timereceived,
      :bip125_replaceable
    ]

    @type t :: %__MODULE__{
            address: String.t(),
            category: String.t(),
            amount: float(),
            label: String.t() | nil,
            vout: integer() | nil,
            confirmations: integer(),
            blockhash: String.t() | nil,
            blockheight: integer() | nil,
            blockindex: integer() | nil,
            blocktime: integer() | nil,
            txid: String.t(),
            walletconflicts: list(String.t()),
            time: integer() | nil,
            timereceived: integer() | nil,
            bip125_replaceable: String.t() | nil
          }
  end

  @enforce_keys [:result, :error, :id]

  defstruct [
    :result,
    :error,
    :id
  ]

  @type t :: %__MODULE__{
          result: list(Transaction.t()),
          error: any(),
          id: String.t()
        }

  @doc """
  Decodes JSON string into a ListTransactions struct.
  """
  def from_json(json_string) do
    with {:ok, decoded} <- Jason.decode(json_string),
         {:ok, response} <- parse(decoded) do
      {:ok, response}
    end
  end

  defp parse(%{"result" => nil, "error" => error, "id" => id}) do
    {:ok,
     %__MODULE__{
       result: [],
       error: error,
       id: id
     }}
  end

  defp parse(%{"result" => result, "error" => error, "id" => id}) do
    {:ok,
     %__MODULE__{
       result: Enum.map(result, &parse_transaction/1),
       error: error,
       id: id
     }}
  end

  defp parse_transaction(tx) do
    %Transaction{
      address: tx["address"],
      category: tx["category"],
      amount: tx["amount"],
      label: tx["label"],
      vout: tx["vout"],
      confirmations: tx["confirmations"],
      blockhash: tx["blockhash"],
      blockheight: tx["blockheight"],
      blockindex: tx["blockindex"],
      blocktime: tx["blocktime"],
      txid: tx["txid"],
      walletconflicts: tx["walletconflicts"],
      time: tx["time"],
      timereceived: tx["timereceived"],
      bip125_replaceable: tx["bip125-replaceable"]
    }
  end
end
