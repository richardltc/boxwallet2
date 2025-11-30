defmodule BoxWallet.Coins.Divi.GetMNSyncStatus do
  @moduledoc """
  Represents a wallet RPC mnsyncstatus response.
  """

  defmodule Result do
    @enforce_keys [
      :IsBlockchainSynced,
      :timestampOfLastMasternodeListUpdate,
      :timestampOfLastMasternodeWinnerUpdate,
      :timestampOfLastFailedSync,
      :countOfFailedSyncAttempts,
      :nominalNumberOfMasternodeBroadcastsReceived,
      :nominalNumberOfMasternodeWinnersReceived,
      :fulfilledMasternodeListSyncRequests,
      :fulfilledMasternodeWinnerSyncRequests,
      :currentMasternodeSyncStatus,
      :totalSuccessivePeerSyncRequests
    ]

    defstruct [
      :IsBlockchainSynced,
      :timestampOfLastMasternodeListUpdate,
      :timestampOfLastMasternodeWinnerUpdate,
      :timestampOfLastFailedSync,
      :countOfFailedSyncAttempts,
      :nominalNumberOfMasternodeBroadcastsReceived,
      :nominalNumberOfMasternodeWinnersReceived,
      :fulfilledMasternodeListSyncRequests,
      :fulfilledMasternodeWinnerSyncRequests,
      :currentMasternodeSyncStatus,
      :totalSuccessivePeerSyncRequests
    ]

    @type t :: %__MODULE__{
            IsBlockchainSynced: boolean(),
            timestampOfLastMasternodeListUpdate: integer(),
            timestampOfLastMasternodeWinnerUpdate: integer(),
            timestampOfLastFailedSync: integer(),
            countOfFailedSyncAttempts: integer(),
            nominalNumberOfMasternodeBroadcastsReceived: integer(),
            nominalNumberOfMasternodeWinnersReceived: integer(),
            fulfilledMasternodeListSyncRequests: integer(),
            fulfilledMasternodeWinnerSyncRequests: integer(),
            currentMasternodeSyncStatus: integer(),
            totalSuccessivePeerSyncRequests: integer()
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
  Decodes JSON string into a GetMNSyncStatus struct
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
      IsBlockchainSynced: result["IsBlockchainSynced"],
      timestampOfLastMasternodeListUpdate: result["timestampOfLastMasternodeListUpdate"],
      timestampOfLastMasternodeWinnerUpdate: result["timestampOfLastMasternodeWinnerUpdate"],
      timestampOfLastFailedSync: result["timestampOfLastFailedSync"],
      countOfFailedSyncAttempts: result["countOfFailedSyncAttempts"],
      nominalNumberOfMasternodeBroadcastsReceived:
        result["nominalNumberOfMasternodeBroadcastsReceived"],
      nominalNumberOfMasternodeWinnersReceived:
        result["nominalNumberOfMasternodeWinnersReceived"],
      fulfilledMasternodeListSyncRequests: result["fulfilledMasternodeListSyncRequests"],
      fulfilledMasternodeWinnerSyncRequests: result["fulfilledMasternodeWinnerSyncRequests"],
      currentMasternodeSyncStatus: result["currentMasternodeSyncStatus"],
      totalSuccessivePeerSyncRequests: result["totalSuccessivePeerSyncRequests"]
    }
  end
end
