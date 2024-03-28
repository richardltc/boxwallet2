export interface GetBlockchainInfoResponse {
	result: GetBlockchainInfoResult;
	error: any;
	id: string;
}

interface GetBlockchainInfoResult {
	chain: string;
	blocks: number;
	headers: number;
	bestblockhash: string;
	difficulty: number;
	verificationprogress: number;
	chainwork: string;
}

// For Divi
// export interface GetInfoResponse {
// 	result: GetInfoResult;
// 	error: any;
// 	id: string;
// }

// interface GetInfoResult {
// 	version: number;
// 	protocolversion: number;
// 	walletversion: number;
// 	balance: number;
// 	stake: number;
// 	locked: boolean;
// 	encrypted: boolean;
// 	blocks: number;
// 	timeoffset: number;
// 	moneysupply: number;
// 	connections: number;
// 	proxy: string;
// 	difficulty: number;
// 	testnet: boolean;
// 	keypoololdest: number;
// 	keypoolsize: number;
// 	unlocked_until: number;
// 	paytxfee: number;
// 	relayfee: number;
// 	errors: string;
// }

export interface GenericResponse {
	result: string;
	error: any;
	id: string;
}

export interface GetNetworkInfoResponse {
	result: GetNetworkInfoResult;
	error: any;
	id: string;
}

export interface GetNetworkInfoResult {
	version: string;
	subversion: string;
	protocolversion: number;
	localservices: string;
	timeoffset: number;
	connections: number;
	networks: Network[];
	relayfee: number;
	localaddresses: any[];
}

export interface Network {
	name: string;
	limited: boolean;
	reachable: boolean;
	proxy: string;
	proxy_randomize_credentials: boolean;
}

export interface Error {
	code: number;
	message: string;
}

export interface GetStakingStatusResponse {
	result: GetStakingStatusResult;
	error: any;
	id: string;
}

interface GetStakingStatusResult {
	validtime: boolean;
	haveconnections: boolean;
	walletunlocked: boolean;
	mintablecoins: boolean;
	staking_balance: number;
	enoughcoins: boolean;
	mnsync: boolean;
	'staking status': boolean;
	'stake split threshold': number;
}

export interface GetWalletInfoResponse {
	result: GetWalletInfoResult;
	error: any;
	id: string;
}

interface GetWalletInfoResult {
	active_wallet: string;
	walletversion: number;
	balance: number;
	unconfirmed_balance: number;
	immature_balance: number;
	spendable_balance: number;
	vaulted_balance: number;
	txcount: number;
	keypoolsize: number;
	unlocked_until: number;
	encryption_status: string;
}
