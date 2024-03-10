export interface CoinData {
	isCoreFilesDownloaded: boolean;
	isRunning: boolean;
	walletVersion?: string;
	syncProgress?: number; // Percentage 0-100
}

export interface CoinClientAdapter {
	// downloadCoreFiles(): Promise<void>; // not required?
	startDaemon(): Promise<void>;
	stopDaemon(): Promise<void>;
	// getCoinData(): Promise<CoinData>;
}
