export interface GetBlockchainInfo {
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

export interface GetInfo {
	result: GetInfoResult;
	error: any;
	id: string;
}

interface GetInfoResult {
	version: number;
	protocolversion: number;
	walletversion: number;
	balance: number;
	stake: number;
	locked: boolean;
	encrypted: boolean;
	blocks: number;
	timeoffset: number;
	moneysupply: number;
	connections: number;
	proxy: string;
	difficulty: number;
	testnet: boolean;
	keypoololdest: number;
	keypoolsize: number;
	unlocked_until: number;
	paytxfee: number;
	relayfee: number;
	errors: string;
}

export interface StopAPIResponse {
	result: string;
	error: any;
	id: string;
}
