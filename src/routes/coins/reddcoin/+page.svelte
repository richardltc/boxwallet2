<script lang="ts">
	import {type BWAPIResponse, CoinMethodType, CoinType} from '$lib/bwtypes';
	import CoinStatus from '$lib/CoinStatus.svelte';
	import {onMount} from 'svelte';
	import type {CoinAPIResponse} from '$lib/bwtypes.js';
	import type {GetBlockchainInfo, GetInfo} from '$lib/rdd_types.js';

	let bw_api_response: BWAPIResponse;
	let coin_getblockchaininfo: GetBlockchainInfo;
	let coin_getinfo_response: GetInfo;
	let coin_api_response: CoinAPIResponse;
	let core_files_downloaded = false;
	let result = {};
	let getblockchaininfo_interval_id: ReturnType<typeof setInterval>;
	let getinfo_interval_id: ReturnType<typeof setInterval>;
	let is_ready_interval_id: ReturnType<typeof setInterval>;
	let is_ready = false;
	let is_working = false;
	let is_running = false;
	let wallet_connections: number;
	let wallet_offline: boolean;
	let wallet_verification_progress: number;
	let daemon_is_ready: null | boolean = false;
	let daemon_is_running: null | boolean = false;
	// $: is_running = daemon_is_running
	$: {
		if (daemon_is_running) {
			is_running = true;
		} else {
			is_running = false;
		}
		if (daemon_is_ready) {
			is_ready = true;
		} else {
			is_ready = false;
		}
	}



	onMount(async () => {
		await doGetCoreStatusAPIRequest(CoinMethodType.get_core_status);
	});

	// const doCoinAPIRequest = async () => {
	// 	const response = await fetch('http://localhost:5173/coins/reddcoin/api', {
	// 		method: 'POST',
	// 		body: JSON.stringify({
	// 			coin_type: CoinType.reddcoin,
	// 			method_type: CoinMethodType.get_info
	// 		})
	// 	});
	//
	// 	coin_getinfo_response = await response.json();
	// 	wallet_connections = coin_getinfo_response.result.connections;
	// 	if (bw_api_response.is_ready === true) {
	// 		is_working = false;
	// 		clearInterval(is_ready_interval_id);
	// 	}
	// 	result = JSON.stringify(bw_api_response);
	// };

	const isReady = async () => {
		console.log(`isReady fired...`);
		const response = await fetch('http://localhost:5173/coins/reddcoin/api', {
			method: 'POST',
			body: JSON.stringify({
				coin_type: CoinType.reddcoin,
				method_type: CoinMethodType.is_ready
			})
		});

		bw_api_response = await response.json();
		console.log(`isReady json response: ${bw_api_response}`);
		const json_result = JSON.stringify(bw_api_response);
		console.log(`isReady json response: ${json_result}`);
		daemon_is_ready = bw_api_response.is_ready;
		daemon_is_running = bw_api_response.is_running;
		if (bw_api_response.is_ready === true) {
			is_working = false;
			wallet_offline = false;
			clearInterval(is_ready_interval_id);
			getinfo_interval_id = setInterval(async () => {
				await doGetCoinInfoAPIRequest(CoinMethodType.get_info);
			}, 3000);
		}
		result = JSON.stringify(bw_api_response);
	};
	// async function doCoreAPIRequest(cmt: CoinMethodType) {
	// 	if (cmt === CoinMethodType.start_daemon) {
	// 		is_working = true;
	// 		is_ready_interval_id = setInterval(isReady, 2000);
	// 	}
	//
	// 	const response = await fetch('http://localhost:5173/coins/reddcoin/api', {
	// 		method: 'POST',
	// 		body: JSON.stringify({
	// 			coin_type: CoinType.reddcoin,
	// 			method_type: cmt //CoinMethodType.is_running
	// 		})
	// 	});
	//
	// 	bw_api_response = await response.json();
	// 	const json_result = JSON.stringify(bw_api_response);
	// 	console.log(`doPost json response: ${json_result}`);
	// 	console.log(`doPost is_running response: ${bw_api_response.is_running}`);
	// 	daemon_is_ready = bw_api_response.is_ready;
	// 	daemon_is_running = bw_api_response.is_running;
	// 	if (bw_api_response.core_files_exists) {
	// 		core_files_downloaded = true;
	// 	}
	// }

	async function doGetBlockchainInfoAPIRequest(cmt: CoinMethodType) {
		const response = await fetch('http://localhost:5173/coins/reddcoin/api', {
			method: 'POST',
			body: JSON.stringify({
				coin_type: CoinType.reddcoin,
				method_type: cmt
			})
		});

		coin_getblockchaininfo = await response.json();
		const json_result = JSON.stringify(coin_getblockchaininfo);
		console.log(`doPost json response: ${json_result}`);
		wallet_verification_progress = coin_getblockchaininfo.result.verificationprogress;
	}

	async function doGetCoinInfoAPIRequest(cmt: CoinMethodType) {
		const response = await fetch('http://localhost:5173/coins/reddcoin/api', {
			method: 'POST',
			body: JSON.stringify({
				coin_type: CoinType.reddcoin,
				method_type: cmt
			})
		});

		coin_getinfo_response = await response.json();
		const json_result = JSON.stringify(coin_getinfo_response);
		console.log(`doPost json response: ${json_result}`);
		wallet_connections = coin_getinfo_response.result.connections
		if (wallet_connections > 0) {
			getinfo_interval_id = setInterval(async () => {
				await doGetBlockchainInfoAPIRequest(CoinMethodType.get_blockchain_info);
			}, 3000);
		}
	}

	async function doGetCoreStatusAPIRequest(cmt: CoinMethodType) {
		const response = await fetch('http://localhost:5173/coins/reddcoin/api', {
			method: 'POST',
			body: JSON.stringify({
				coin_type: CoinType.reddcoin,
				method_type: cmt
			})
		});

		bw_api_response = await response.json();
		const json_result = JSON.stringify(bw_api_response);
		console.log(`doPost json response: ${json_result}`);
		console.log(`doPost is_running response: ${bw_api_response.is_running}`);
		// daemon_is_ready = bw_api_response.is_ready;
		// daemon_is_running = bw_api_response.is_running;
		// if (daemon_is_ready) {
		// 	wallet_offline = false;
		// }
		if (bw_api_response.core_files_exists) {
			core_files_downloaded = true;
		}
		await isReady()
	}

	// async function doButtons() {
	// 	// await doPost(CoinMethodType.is_running)
	// 	await doCoreAPIRequest(CoinMethodType.get_core_status);
	// }

	async function doStartWalletAPIRequest(cmt: CoinMethodType) {
		if (cmt === CoinMethodType.start_daemon) {
			is_working = true;
			is_ready_interval_id = setInterval(isReady, 2000);
		}

		const response = await fetch('http://localhost:5173/coins/reddcoin/api', {
			method: 'POST',
			body: JSON.stringify({
				coin_type: CoinType.reddcoin,
				method_type: cmt
			})
		});

		bw_api_response = await response.json();
		const json_result = JSON.stringify		// if (bw_api_response.core_files_exists) {
		// 	core_files_downloaded = true;
		// }
(bw_api_response);
		console.log(`doPost json response: ${json_result}`);
		console.log(`doPost is_running response: ${bw_api_response.is_running}`);
		// daemon_is_ready = bw_api_response.is_ready;
		// daemon_is_running = bw_api_response.is_running;
		// if (bw_api_response.core_files_exists) {
		// 	core_files_downloaded = true;
		// }
	}

	async function doStopWalletAPIRequest(cmt: CoinMethodType) {
		// Stop all timers
		clearInterval(getinfo_interval_id);
		clearInterval(getblockchaininfo_interval_id);
		const response = await fetch('http://localhost:5173/coins/reddcoin/api', {
			method: 'POST',
			body: JSON.stringify({
				coin_type: CoinType.reddcoin,
				method_type: cmt
			})
		});

		if (cmt === CoinMethodType.stop_daemon) {
			wallet_connections = 0;
			wallet_offline = true;
		}

		bw_api_response = await response.json();
		const json_result = JSON.stringify(bw_api_response);
		console.log(`doPost json response: ${json_result}`);
	}

</script>

<div class="container mx-auto p-8 space-y-4">
	<h1 class="h1">ReddCoin - The social currency</h1>
	<p>
		With over 60,000 users in 50+ countries, Redd allows you to share, tip, and donate to anyone,
		anywhere.
	</p>
	<section>
		<CoinStatus {core_files_downloaded} {is_ready} {is_working} {wallet_verification_progress} {wallet_connections} {wallet_offline}/>
	</section>
	<section>
		<button
			disabled={is_running}
			class="btn variant-filled-secondary"
			type="button"
			on:click={() => doStartWalletAPIRequest(CoinMethodType.start_daemon)}
		>
			Start
		</button>
		<button
			class="btn variant-filled-primary"
			type="button"
			on:click={() => doGetCoreStatusAPIRequest(CoinMethodType.is_running)}
		>
			Is Running?
		</button>
		<button
			disabled={!is_running}
			class="btn variant-filled-tertiary"
			type="button"
			on:click={() => doStopWalletAPIRequest(CoinMethodType.stop_daemon)}
		>
			Stop
		</button>
		<p>Result:</p>
		<pre>
{result}
</pre>
	</section>
</div>
