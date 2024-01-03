import type { RequestEvent } from './$types';
import type { ApiRequest, BWAPIResponse } from '$lib/bwtypes';
import { CoinMethodType, CoinType } from '$lib/bwtypes';
import { download_file } from '$lib/web_utils';
import * as os from 'os';
import ReddCoin from '$lib/rdd';
import type { GetBlockchainInfoResponse, GetInfoResponse, GenericResponse } from '$lib/rdd_types';

const home_dir = os.homedir();

export async function POST({ request }: RequestEvent) {
	const data_object: any = await request.json();

	// method_types include: core_files_exist, start_daemon, stop_daemon
	const method_type: CoinMethodType = data_object.method_type;
	const redd_coin = await ReddCoin.getInstance('/home/richard/.reddcoin/reddcoin.conf');

	let get_blockchain_info_api_response: GetBlockchainInfoResponse;
	let get_info_api_response: GetInfoResponse;
	let core_files_exist = false;
	const bw_api_response: BWAPIResponse = {
		core_files_exists: null,
		is_ready: null,
		is_running: null
	};
	let is_ready: boolean;
	let is_running: boolean;
	let generic_api_response: GenericResponse;

	// Wait for the asynchronous initialization to complete

	switch (method_type) {
		case CoinMethodType.core_files_exist: {
			// Check that core files exist
			let result = {};

			const api_request: ApiRequest = {
				boxwallet_dir: home_dir + '/.boxwallet/',
				coin_type: CoinType.reddcoin,
				method_type: CoinMethodType.core_files_exist
			};

			console.log('Talking to Go app');
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
		// switch (platform) {
		// 	case 'linux':
		// 		if (fs.existsSync(home_dir + '/.boxwallet/' + cli_file_lin)) {
		// 			// File exists in path
		// 			console.log('file exists ' + home_dir + '/.boxwallet/' + cli_file_lin);
		// 			return new Response('true');
		// 		} else {
		// 			// File doesn't exist in path
		// 			console.log('file DOES NOT exist ' + home_dir + '/.boxwallet/' + cli_file_lin);
		// 			return new Response('false');
		// 		}
		// }

		//////////////////////////////
		// DOWNLOAD_CORE_FILES
		case CoinMethodType.download_core_files:
			// First, make sure we get the correct file for what we're running on
			console.log('going to download core files from: ' + redd_coin.download_link);
			await redd_coin.DownloadCoreFiles();
			console.log('Download complete from server');
			// decompress(home_dir + '/.boxwallet/' + download_file_lin64);
			return new Response('download_complete');

		//////////////////////////////
		// GET_BLOCKCHAIN_INFO
		case CoinMethodType.get_blockchain_info:
			// stop the Daemon
			// console.log('Hitting get_blockchain_info...');
			get_blockchain_info_api_response = await redd_coin.GetBlockchainInfo();
			// console.log(`Got ${JSON.stringify(get_blockchain_info_api_response)}...`);
			return new Response(JSON.stringify(get_blockchain_info_api_response));

		//////////////////////////////
		// GET_INFO
		case CoinMethodType.get_info:
			get_info_api_response = await redd_coin.GetInfo();
			return new Response(JSON.stringify(get_info_api_response));
		case CoinMethodType.get_core_status:
			// Check whether redd Daemon is running
			console.log('Checking if Daemon is ready...');
			core_files_exist = await redd_coin.CoreFilesExist();
			is_ready = await redd_coin.CoinDaemonIsReady();
			is_running = await redd_coin.CoinDaemonIsRunning();
			if (is_ready) {
				console.log('Coin daemon is ready');
			} else {
				console.log('Coin daemon is not ready');
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
			console.log('Checking if Daemon is ready...');
			is_ready = await redd_coin.CoinDaemonIsReady();
			is_running = await redd_coin.CoinDaemonIsRunning();
			if (is_ready) {
				console.log('Coin daemon is ready');
			} else {
				console.log('Coin daemon is not ready');
			}
			bw_api_response.is_ready = is_ready;
			bw_api_response.is_running = is_running;
			// console.log(`Returning ${JSON.stringify(bw_api_response)})...`);
			return new Response(JSON.stringify(bw_api_response));

		//////////////////////////////
		// IS_RUNNING
		case CoinMethodType.is_running:
			// Check whether redd Daemon is running
			console.log('Checking if Daemon is running...');
			is_running = await redd_coin.CoinDaemonIsRunning();
			if (is_running) {
				console.log('Coin daemon is running');
			} else {
				console.log('Coin daemon is not running');
			}
			bw_api_response.is_running = is_running;
			// console.log(`Returning ${JSON.stringify(bw_api_response)})...`);
			return new Response(JSON.stringify(bw_api_response));

		//////////////////////////////
		// START
		case CoinMethodType.start_daemon:
			// start the Daemon
			console.log('Hitting start daemon...');
			await redd_coin.StartDaemon();
			console.log('reddcoin daemon is starting...');
			bw_api_response.is_running = false;
			return new Response(JSON.stringify(bw_api_response));

		//////////////////////////////
		// STOP
		case CoinMethodType.stop_daemon:
			// stop the Daemon
			console.log('Hitting stop daemon...');
			generic_api_response = await redd_coin.StopDaemon();
			console.log(`Got ${generic_api_response}...`);
			return new Response(JSON.stringify(generic_api_response));

		//////////////////////////////
		// WALLET_UNLOCKFS
		case CoinMethodType.wallet_unlockfs:
			console.log(`Hitting wallet_unlockfs, password received 1: ${data_object.password}...`);
			generic_api_response = await redd_coin.WalletUnlockFS(data_object.password);
			console.log(`Got ${generic_api_response}...`);
			return new Response(JSON.stringify(generic_api_response));
		default:
			// We don't know what the method is, so..
			return new Response('Unknown method: ' + method_type);
	}

	return new Response('Reached end of POST request');
}
