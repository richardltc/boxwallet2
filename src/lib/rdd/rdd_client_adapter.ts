import * as rdd_client from '$lib/rdd/rdd_client';
import type { CoinData, CoinClientAdapter } from '$lib/coin_types';
import type { GetBlockchainInfoResponse, GetNetworkInfoResponse } from '$lib/rdd/rdd_types';

export class RDDClientAdapter implements CoinClientAdapter {
	async startDaemon() {
		await rdd_client.StartDaemonAPIRequest();
		// Update coinData if start is successful
	}

	async stopDaemon() {
		await rdd_client.StopDaemonAPIRequest();
		// Update coinData if stop is successful
	}

	// async getCoinData(): Promise<CoinData> {
	// 	const blockchainInfo: GetBlockchainInfoResponse =
	// 		await rdd_client.GetBlockchainInfoAPIRequest();
	// 	const networkInfo: GetNetworkInfoResponse = await rdd_client.GetNetworkInfoAPIRequest();
	//
	// 	return {
	// 		isCoreFilesDownloaded: true, // Adjust based on your logic
	// 		isRunning: networkInfo.connections > 0, // Assuming connections indicate wallet running
	// 		walletVersion: networkInfo.version,
	// 		syncProgress: blockchainInfo.verificationprogress * 100
	// 	};
	// }
}
