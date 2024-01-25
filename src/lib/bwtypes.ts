export interface ApiRequest {
	boxwallet_dir: string;
	coin_type: CoinType;
	method_type: CoinMethodType;
}

export interface BWAPIResponse {
	core_files_exists: boolean | null;
	is_ready: boolean | null;
	is_running: boolean | null;
}

export enum CoinMethodType {
	core_files_exist,
	download_core_files,
	start_daemon,
	stop_daemon,
	is_running,
	get_network_info,
	is_ready,
	get_core_status = 7,
	get_blockchain_info,
	wallet_unlockfs
}

export enum CoreFileStatusType {
	cfst_not_installed,
	cfst_downloading,
	cfst_installed
}

export enum WalletRunningStatusType {
	wrst_starting,
	wrst_stopping,
	wrst_stopped
}
export enum CoinType {
	divi,
	pivx,
	reddcoin
}

export enum IconStatusType {
	is_disabled,
	is_enabled,
	is_enabled_spinning
}
