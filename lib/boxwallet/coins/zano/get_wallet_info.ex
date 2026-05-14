defmodule BoxWallet.Coins.Zano.GetWalletInfo do
  @moduledoc """
  Represents the synthesized wallet info for Zano, built from a combination
  of simplewallet `getbalance` + `getaddress` calls plus the in-memory
  encryption status tracked by the BoxWallet GenServer.

  Unlike the Bitcoin-Core-style `getwalletinfo`, Zano has no single RPC that
  returns all this in one call.

  Balance fields are in ZANO (already divided down from atomic units).
  """

  defmodule Result do
    defstruct active_wallet: nil,
              balance: 0.0,
              unconfirmed_balance: 0.0,
              immature_balance: 0.0,
              address: "",
              encryption_status: "unknown"

    @type t :: %__MODULE__{
            active_wallet: String.t() | nil,
            balance: float(),
            unconfirmed_balance: float(),
            immature_balance: float(),
            address: String.t(),
            encryption_status: String.t()
          }
  end

  defstruct [:result, :error, :id]

  @type t :: %__MODULE__{
          result: Result.t() | nil,
          error: any(),
          id: any()
        }
end
