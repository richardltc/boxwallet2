import type { RequestEvent } from './$types';
import type { ApiRequest, BWAPIResponse } from '$lib/bw_types';
import { CoinMethodType, CoinType } from '$lib/bw_types';
import { download_file } from '$lib/web_utils';
import * as os from 'os';
import ReddCoin from '$lib/rdd/rdd';
import type {
	GetBlockchainInfoResponse,
	GetNetworkInfoResponse,
	GenericResponse
} from '$lib/rdd/rdd_types';
import path from 'path';

const home_dir_boxwallet = '.boxwallet';
const home_dir_coin_lin = '.reddcoin';
const home_dir_coin_win = 'REDDCOIN';
const conf_file = 'reddcoin.conf';

const coin_conf_file = path.join(os.homedir(), home_dir_coin_lin, conf_file);
const coin = await ReddCoin.getInstance(coin_conf_file);

export async function POST({ request }: RequestEvent) {
	const data_object: any = await request.json();

	// method_types include: core_files_exist, start_daemon, stop_daemon
	const method_type: CoinMethodType = data_object.method_type;

	let get_blockchain_info_api_response: GetBlockchainInfoResponse;
	let get_network_info_api_response: GetNetworkInfoResponse;
	let core_files_exist = false;
	const bw_api_response: BWAPIResponse = {
		core_files_exists: null,
		is_ready: null,
		is_running: null
	};
	let is_ready: boolean;
	let is_running: boolean;
	let wallet_exists: boolean;
	let generic_api_response: GenericResponse;

	switch (method_type) {
		/////////////////////////////
		// CORE_FILES_EXIST
		case CoinMethodType.core_files_exist: {
			// Check that core files exist
			let result = {};

			const api_request: ApiRequest = {
				boxwallet_dir: path.join(os.homedir(), home_dir_boxwallet),
				coin_type: CoinType.reddcoin,
				method_type: CoinMethodType.core_files_exist
			};

			const api_response = await fetch('http://127.0.0.1:3000/api/v1/coin', {
				method: 'POST',
				body: JSON.stringify(api_request)
			});

			console.log('Got response...');
			const api_response_json: BWAPIResponse = await api_response.json();
			console.table({ api_response_json });
			result = JSON.stringify(api_response_json);
			console.log('JSON response...');
			console.log(result);
			return new Response('true');

			break;
		}

		//////////////////////////////
		// DOWNLOAD_CORE_FILES
		case CoinMethodType.download_core_files:
			// First, make sure we get the correct file for what we're running on
			console.log(
				`Attempting to download the ${coin.coin_name} core files from: ` + coin.download_link
			);
			await coin.DownloadCoreFiles();
			console.log('Download complete from server');
			core_files_exist = await coin.CoreFilesExist();
			bw_api_response.core_files_exists = core_files_exist;
			return new Response(JSON.stringify(bw_api_response));

		//////////////////////////////
		// GET_BLOCKCHAIN_INFO
		case CoinMethodType.get_blockchain_info:
			// stop the Daemon
			get_blockchain_info_api_response = await coin.GetBlockchainInfo();
			return new Response(JSON.stringify(get_blockchain_info_api_response));

		//////////////////////////////
		// GET_NETWORK_INFO
		case CoinMethodType.get_network_info:
			get_network_info_api_response = await coin.GetNetworkInfo();
			return new Response(JSON.stringify(get_network_info_api_response));

		//////////////////////////////
		// GET_CORE_STATUS
		case CoinMethodType.get_core_status:
			// Check whether redd Daemon is running
			console.log(`Checking if ${coin.coin_name} Daemon is ready...`);
			core_files_exist = await coin.CoreFilesExist();
			is_ready = await coin.CoinDaemonIsReady();
			is_running = await coin.CoinDaemonIsRunning();
			if (is_ready) {
				console.log(`${coin.coin_name} Daemon is ready`);
				wallet_exists = await coin.WalletExists('main');
				if (wallet_exists) {
					console.log('main wallet exists');
				} else {
					console.log('main wallet does not exist');
				}
			} else {
				console.log(`${coin.coin_name} Daemon is not ready`);
			}
			bw_api_response.core_files_exists = core_files_exist;
			bw_api_response.is_ready = is_ready;
			bw_api_response.is_running = is_running;
			// console.log(`Returning ${JSON.stringify(bw_api_response)})...`);
			return new Response(JSON.stringify(bw_api_response));

		//////////////////////////////
		// IS_READY
		case CoinMethodType.is_ready:
			// Check whether redd Daemon is running
			console.log(`Checking if ${coin.coin_name} Daemon is ready...`);
			is_ready = await coin.CoinDaemonIsReady();
			is_running = await coin.CoinDaemonIsRunning();
			if (is_ready) {
				console.log(`${coin.coin_name} Daemon is ready`);
			} else {
				console.log(`${coin.coin_name} Saemon is not ready`);
			}
			bw_api_response.is_ready = is_ready;
			bw_api_response.is_running = is_running;
			// console.log(`Returning ${JSON.stringify(bw_api_response)})...`);
			return new Response(JSON.stringify(bw_api_response));

		//////////////////////////////
		// IS_RUNNING
		case CoinMethodType.is_running:
			// Check whether redd Daemon is running
			console.log(`Checking if ${coin.coin_name} Daemon is running...`);
			is_running = await coin.CoinDaemonIsRunning();
			if (is_running) {
				console.log(`${coin.coin_name} Daemon is running`);
			} else {
				console.log(`${coin.coin_name} Daemon is not running`);
			}
			bw_api_response.is_running = is_running;
			// console.log(`Returning ${JSON.stringify(bw_api_response)})...`);
			return new Response(JSON.stringify(bw_api_response));

		//////////////////////////////
		// START
		case CoinMethodType.start_daemon:
			// start the Daemon
			console.log(`Attempting to  start ${coin.coin_name} Daemon...`);
			await coin.StartDaemon();
			console.log(`${coin.coin_name} daemon is starting...`);
			bw_api_response.is_running = false;
			return new Response(JSON.stringify(bw_api_response));

		//////////////////////////////
		// STOP
		case CoinMethodType.stop_daemon:
			// stop the Daemon
			console.log(`Attempting to stop ${coin.coin_name} Daemon...`);
			generic_api_response = await coin.StopDaemon();
			console.log(`Got ${generic_api_response}...`);
			return new Response(JSON.stringify(generic_api_response));

		//////////////////////////////
		// WALLET_UNLOCKFS
		case CoinMethodType.wallet_unlockfs:
			console.log(`Hitting wallet_unlockfs, password received 1: ${data_object.password}...`);
			generic_api_response = await coin.WalletUnlockFS(data_object.password);
			console.log(`Got ${generic_api_response}...`);
			return new Response(JSON.stringify(generic_api_response));
		default:
			// We don't know what the method is, so..
			return new Response('Unknown method: ' + method_type);
	}

	return new Response('Reached end of POST request');
}
