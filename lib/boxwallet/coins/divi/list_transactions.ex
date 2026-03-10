defmodule BoxWallet.Coins.Divi.ListTransactions do
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
      :involveswatchonly,
      :address,
      :amount,
      :vout,
      :category,
      :account,
      :confirmations,
      :bcconfirmations,
      :generated,
      :blockhash,
      :blockindex,
      :blocktime,
      :txid,
      :baretxid,
      :walletconflicts,
      :time,
      :timereceived
    ]

    @type t :: %__MODULE__{
            involveswatchonly: boolean() | nil,
            address: String.t(),
            amount: float(),
            vout: integer() | nil,
            category: String.t(),
            account: String.t() | nil,
            confirmations: integer(),
            bcconfirmations: integer() | nil,
            generated: boolean() | nil,
            blockhash: String.t() | nil,
            blockindex: integer() | nil,
            blocktime: integer() | nil,
            txid: String.t(),
            baretxid: String.t() | nil,
            walletconflicts: list(String.t()),
            time: integer() | nil,
            timereceived: integer() | nil
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
      involveswatchonly: tx["involvesWatchonly"],
      address: tx["address"],
      amount: tx["amount"],
      vout: tx["vout"],
      category: tx["category"],
      account: tx["account"],
      confirmations: tx["confirmations"],
      bcconfirmations: tx["bcconfirmations"],
      generated: tx["generated"],
      blockhash: tx["blockhash"],
      blockindex: tx["blockindex"],
      blocktime: tx["blocktime"],
      txid: tx["txid"],
      baretxid: tx["baretxid"],
      walletconflicts: tx["walletconflicts"],
      time: tx["time"],
      timereceived: tx["timereceived"]
    }
  end
end
