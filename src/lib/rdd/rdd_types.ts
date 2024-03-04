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
	version: number;
	subversion: string;
	protocolversion: number;
	localservices: string;
	localservicesnames: string[];
	localrelay: boolean;
	timeoffset: number;
	networkactive: boolean;
	connections: number;
	connections_in: number;
	connections_out: number;
	networks: Network[];
	relayfee: number;
	incrementalfee: number;
	localaddresses: any[];
	warnings: string;
}

export interface Network {
	name: string;
	limited: boolean;
	reachable: boolean;
	proxy: string;
	proxy_randomize_credentials: boolean;
}

export interface GetWalletInfo {
	result: any;
	error: Error;
	id: string;
}

export interface Error {
	code: number;
	message: string;
}
