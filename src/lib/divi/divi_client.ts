import type {
	GetBlockchainInfoResponse,
	GetNetworkInfoResponse,
	GetStakingStatusResponse,
	GetWalletInfoResponse
} from '$lib/divi/divi_types';
import { PUBLIC_HOST_IP } from '$env/static/public';
import {
	type BWAPIResponse,
	CoinMethodType,
	CoinType,
	CoreFileStatusType,
	DaemonRunningStatusType
} from '$lib/bw_types';
import { walletConnections, coinWalletVersion } from '$lib/divi/divi_getnetworkinfo_store';
import { walletUnlockedUntil } from '$lib/divi/divi_getwalletinfo_store';
import {
	blocks,
	difficulty,
	headers,
	verificationProgress
} from '$lib/divi/divi_getblockchaininfo_store';
import { coreFileStatus, daemonRunningStatus } from '$lib/divi/divi_core_status_store';
import { stakingStatus } from '$lib/divi/divi_getstakingstatus_store';
// import { getModalStore, getToastStore, type ToastSettings } from '@skeletonlabs/skeleton';

let bw_api_response: BWAPIResponse;
let coin_get_blockchain_info: GetBlockchainInfoResponse;
let coin_get_network_info_response: GetNetworkInfoResponse;
let coin_get_staking_status_response: GetStakingStatusResponse;
let coin_get_wallet_info_response: GetWalletInfoResponse;
let core_files_status: CoreFileStatusType;
let daemon_is_ready: null | boolean = false;
let daemon_is_running: null | boolean = false;
let is_ready_interval_id: ReturnType<typeof setInterval>;
let getblockchaininfo_interval_id: ReturnType<typeof setInterval>;
let getnetworkinfo_interval_id: ReturnType<typeof setInterval>;
let getwalletinfo_interval_id: ReturnType<typeof setInterval>;
let timer_get_blockchain_info_running = false;
let timer_get_network_info_running = false;
let timer_get_wallet_info_running = false;

const coin_name_lower = 'divi';

/////////////////////////////////
// Get Blockchain Info
export async function GetBlockchainInfoAPIRequest(cmt: CoinMethodType) {
	const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/${coin_name_lower}/api`, {
		method: 'POST',
		body: JSON.stringify({
			coin_type: CoinType.divi,
			method_type: cmt
		})
	});

	coin_get_blockchain_info = await response.json();
	const json_result = JSON.stringify(coin_get_blockchain_info);
	console.log(`doPost json response: ${json_result}`);
	// block_height = coin_get_blockchain_info.result.blocks;
	headers.set(coin_get_blockchain_info.result.headers);
	blocks.set(coin_get_blockchain_info.result.blocks);
	difficulty.set(coin_get_blockchain_info.result.difficulty);

	verificationProgress.set(coin_get_blockchain_info.result.verificationprogress);
}

export async function GetCoreStatusAPIRequest(cmt: CoinMethodType) {
	const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/${coin_name_lower}/api`, {
		method: 'POST',
		body: JSON.stringify({
			coin_type: CoinType.divi,
			method_type: cmt
		})
	});

	bw_api_response = await response.json();
	const json_result = JSON.stringify(bw_api_response);
	if (bw_api_response.is_running) {
		daemonRunningStatus.set(DaemonRunningStatusType.drst_running);
	}
	if (bw_api_response.core_files_exists) {
		console.log('core files exist...');
		coreFileStatus.set(CoreFileStatusType.cfst_installed);
	}
	// console.log('Running isReady...');
	// await isReady();
}

/////////////////////////////////
// Get Staking Status
export async function GetStakingStatusAPIRequest(cmt: CoinMethodType) {
	const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/${coin_name_lower}/api`, {
		method: 'POST',
		body: JSON.stringify({
			coin_type: CoinType.divi,
			method_type: cmt
		})
	});

	coin_get_staking_status_response = await response.json();
	const json_result = JSON.stringify(coin_get_staking_status_response);
	console.log(`doPost json response: ${json_result}`);
	// block_height = coin_get_blockchain_info.result.blocks;

	stakingStatus.set(coin_get_staking_status_response.result['staking status']);
}

/////////////////////////////////
// Get Wallet Info
export async function GetWalletInfoAPIRequest(cmt: CoinMethodType) {
	const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/${coin_name_lower}/api`, {
		method: 'POST',
		body: JSON.stringify({
			coin_type: CoinType.divi,
			method_type: cmt
		})
	});

	coin_get_wallet_info_response = await response.json();
	const json_result = JSON.stringify(coin_get_wallet_info_response);
	console.log(`GetWalletInfo json response: ${json_result}`);
	// block_height = coin_get_blockchain_info.result.blocks;

	console.log(
		`Setting unlock_until in divi_client.ts to: ${coin_get_wallet_info_response.result.unlocked_until}`
	);
	walletUnlockedUntil.set(coin_get_wallet_info_response.result.unlocked_until);
}

/////////////////////////////////
// Get Network Info
export async function GetNetworkInfoAPIRequest(cmt: CoinMethodType) {
	const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/${coin_name_lower}/api`, {
		method: 'POST',
		body: JSON.stringify({
			coin_type: CoinType.divi,
			method_type: cmt
		})
	});

	coin_get_network_info_response = await response.json();
	const json_result = JSON.stringify(coin_get_network_info_response);
	console.log(`doPost json response: ${json_result}`);
	console.log(`Setting walletConnections: ${coin_get_network_info_response.result.connections}`);
	walletConnections.set(coin_get_network_info_response.result.connections);
	coinWalletVersion.set(coin_get_network_info_response.result.version);
	// wallet_unlocked_until = coin_get_network_info_response.result.unlocked_until;
	// walletUnlockedUntil.set(coin_get_network_info_response.result.unlocked_until);
	if (coin_get_network_info_response.result.connections > 0) {
		if (!timer_get_blockchain_info_running) {
			timer_get_blockchain_info_running = true;
			console.log('Setting GetBlockchainInfo timer');
			getblockchaininfo_interval_id = setInterval(async () => {
				await GetBlockchainInfoAPIRequest(CoinMethodType.get_blockchain_info);
			}, 10000);
			await GetBlockchainInfoAPIRequest(CoinMethodType.get_blockchain_info);
		}

		if (!timer_get_wallet_info_running) {
			timer_get_wallet_info_running = true;
			console.log('Setting GetWalletInfo timer');
			getwalletinfo_interval_id = setInterval(async () => {
				await GetWalletInfoAPIRequest(CoinMethodType.get_wallet_info);
			}, 10000);
			await GetWalletInfoAPIRequest(CoinMethodType.get_wallet_info);
		}
	}
}

//////////////////////////////
// Is Ready
export const IsReady = async () => {
	const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/${coin_name_lower}/api`, {
		method: 'POST',
		body: JSON.stringify({
			coin_type: CoinType.divi,
			method_type: CoinMethodType.is_ready
		})
	});

	bw_api_response = await response.json();
	const json_result = JSON.stringify(bw_api_response);
	console.log(`IsReady json response: ${json_result}`);
	daemon_is_ready = bw_api_response.is_ready;
	daemon_is_running = bw_api_response.is_running;
	if (bw_api_response.is_ready === true) {
		// isWorking.set(false);
		daemonRunningStatus.set(DaemonRunningStatusType.drst_running);
		// walletRunningStatus.set(WalletRunningStatusType.wrst_stopped);
		clearInterval(is_ready_interval_id);
		if (!timer_get_network_info_running) {
			timer_get_network_info_running = true;
			getnetworkinfo_interval_id = setInterval(async () => {
				await GetNetworkInfoAPIRequest(CoinMethodType.get_network_info);
			}, 10000);
			await GetNetworkInfoAPIRequest(CoinMethodType.get_network_info);
		}
	}
};

/////////////////////////////////
// Start Daemon
export async function StartDaemonAPIRequest() {
	// isWorking.set(true);
	is_ready_interval_id = setInterval(IsReady, 2000);
	daemonRunningStatus.set(DaemonRunningStatusType.drst_starting);

	const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/${coin_name_lower}/api`, {
		method: 'POST',
		body: JSON.stringify({
			coin_type: CoinType.divi,
			method_type: CoinMethodType.start_daemon
		})
	});

	bw_api_response = await response.json();
	const json_result = JSON.stringify(bw_api_response);
	console.log(`doPost json response: ${json_result}`);
	console.log(`doPost is_running response: ${bw_api_response.is_running}`);
	// daemon_is_ready = bw_api_response.is_ready;
	// daemon_is_running = bw_api_response.is_running;
	// if (bw_api_response.core_files_exists) {
	// 	core_files_downloaded = true;
	// }
}

////////////////////////////////
// Stop Daemon
export async function StopDaemonAPIRequest() {
	// Stop all timers
	clearInterval(getnetworkinfo_interval_id);
	clearInterval(getblockchaininfo_interval_id);
	clearInterval(getwalletinfo_interval_id);
	const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/${coin_name_lower}/api`, {
		method: 'POST',
		body: JSON.stringify({
			coin_type: CoinType.divi,
			method_type: CoinMethodType.stop_daemon
		})
	});

	walletConnections.set(0);
	walletUnlockedUntil.set(-5);
	headers.set(0);
	blocks.set(0);
	difficulty.set(0);
	daemonRunningStatus.set(DaemonRunningStatusType.drst_stopped);

	bw_api_response = await response.json();
	const json_result = JSON.stringify(bw_api_response);
	console.log(`StopWallet json response: ${json_result}`);
}
