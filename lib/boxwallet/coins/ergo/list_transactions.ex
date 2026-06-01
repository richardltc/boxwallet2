defmodule BoxWallet.Coins.Ergo.ListTransactions do
  @moduledoc """
  Parses the response from Ergo's `GET /wallet/transactions` endpoint into a
  list of `Transaction` structs shaped for the shared `CoinTransactions`
  component (which reads `.address`, `.category`, `.amount`, `.confirmations`
  and `.blocktime`).

  NOTE (v1, needs verification against a live node 6.0.2): Ergo's wallet
  transaction objects expose `inputs`/`outputs` boxes (values in nanoERG),
  `inclusionHeight` and `numConfirmations`, but no per-tx unix timestamp. So:
    * `amount` is a best-effort GROSS sum of output box values in ERG (not a
      net wallet delta) — refine to a signed net amount once validated live.
    * `category` defaults to "receive".
    * `blocktime` is nil (the component renders "Pending" for nil).

  `from_json/1` accepts a raw JSON string or an already-decoded list (Req
  decodes JSON response bodies automatically).
  """
  @nano_per_erg 1_000_000_000

  defmodule Transaction do
    @derive Jason.Encoder
    defstruct [
      :txid,
      :address,
      :category,
      :amount,
      :confirmations,
      :inclusion_height,
      :blocktime
    ]

    @type t :: %__MODULE__{
            txid: String.t() | nil,
            address: String.t(),
            category: String.t(),
            amount: float(),
            confirmations: integer(),
            inclusion_height: integer() | nil,
            blocktime: integer() | nil
          }
  end

  def from_json(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, decoded} -> from_json(decoded)
      {:error, reason} -> {:error, reason}
    end
  end

  def from_json(txs) when is_list(txs) do
    {:ok, Enum.map(txs, &parse_transaction/1)}
  end

  def from_json(_), do: {:error, :unexpected_response}

  defp parse_transaction(tx) do
    %Transaction{
      txid: tx["id"],
      address: first_output_address(tx),
      category: "receive",
      amount: output_total_erg(tx),
      confirmations: tx["numConfirmations"] || 0,
      inclusion_height: tx["inclusionHeight"],
      blocktime: nil
    }
  end

  defp output_total_erg(tx) do
    nano =
      (tx["outputs"] || [])
      |> Enum.map(fn out -> out["value"] || 0 end)
      |> Enum.sum()

    nano / @nano_per_erg
  end

  defp first_output_address(tx) do
    case tx["outputs"] do
      [%{"address" => address} | _] when is_binary(address) -> address
      _ -> ""
    end
  end
end
