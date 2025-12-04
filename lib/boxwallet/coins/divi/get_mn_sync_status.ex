defmodule BoxWallet.Coins.Divi.GetMNSyncStatus do
  @moduledoc """
  Represents a wallet RPC mnsyncstatus response.
  """

  defmodule Result do
    @enforce_keys [
      :is_blockchain_synced,
      :timestamp_of_last_masternode_list_update,
      :timestamp_of_last_masternode_winner_update,
      :timestamp_of_last_failed_sync,
      :count_of_failed_sync_attempts,
      :nominal_number_of_masternode_broadcasts_received,
      :nominal_number_of_masternode_winners_received,
      :fulfilled_masternode_list_sync_requests,
      :fulfilled_masternode_winner_sync_requests,
      :current_masternode_sync_status,
      :total_successive_peer_sync_requests
    ]

    defstruct [
      :is_blockchain_synced,
      :timestamp_of_last_masternode_list_update,
      :timestamp_of_last_masternode_winner_update,
      :timestamp_of_last_failed_sync,
      :count_of_failed_sync_attempts,
      :nominal_number_of_masternode_broadcasts_received,
      :nominal_number_of_masternode_winners_received,
      :fulfilled_masternode_list_sync_requests,
      :fulfilled_masternode_winner_sync_requests,
      :current_masternode_sync_status,
      :total_successive_peer_sync_requests
    ]

    @type t :: %__MODULE__{
            is_blockchain_synced: boolean(),
            timestamp_of_last_masternode_list_update: integer(),
            timestamp_of_last_masternode_winner_update: integer(),
            timestamp_of_last_failed_sync: integer(),
            count_of_failed_sync_attempts: integer(),
            nominal_number_of_masternode_broadcasts_received: integer(),
            nominal_number_of_masternode_winners_received: integer(),
            fulfilled_masternode_list_sync_requests: integer(),
            fulfilled_masternode_winner_sync_requests: integer(),
            current_masternode_sync_status: integer(),
            total_successive_peer_sync_requests: integer()
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
  Decodes JSON string into a GetMNSyncStatus struct, and sorts case.
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
      is_blockchain_synced: result["IsBlockchainSynced"],
      timestamp_of_last_masternode_list_update: result["timestampOfLastMasternodeListUpdate"],
      timestamp_of_last_masternode_winner_update: result["timestampOfLastMasternodeWinnerUpdate"],
      timestamp_of_last_failed_sync: result["timestampOfLastFailedSync"],
      count_of_failed_sync_attempts: result["countOfFailedSyncAttempts"],
      nominal_number_of_masternode_broadcasts_received:
        result["nominalNumberOfMasternodeBroadcastsReceived"],
      nominal_number_of_masternode_winners_received:
        result["nominalNumberOfMasternodeWinnersReceived"],
      fulfilled_masternode_list_sync_requests: result["fulfilledMasternodeListSyncRequests"],
      fulfilled_masternode_winner_sync_requests: result["fulfilledMasternodeWinnerSyncRequests"],
      current_masternode_sync_status: result["currentMasternodeSyncStatus"],
      total_successive_peer_sync_requests: result["totalSuccessivePeerSyncRequests"]
    }
  end
end
