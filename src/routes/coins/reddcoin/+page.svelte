<script lang="ts">
	import {
		type BWAPIResponse,
		CoinMethodType,
		CoinType,
		CoreFileStatusType,
		DaemonRunningStatusType
	} from '$lib/bwtypes';
	import CoinStatus from '$lib/CoinStatus.svelte';
	import { PUBLIC_HOST_IP } from '$env/static/public';
	import { onMount } from 'svelte';
	import type { GenericResponse, GetBlockchainInfoResponse, GetNetworkInfoResponse } from '$lib/rdd_types.js';
	import { blocks, difficulty, headers } from '$lib/rdd_getblockchaininfo_store';
	import { coreFileStatus, daemonRunningStatus } from '$lib/bw_store';
	import { walletConnections, walletUnlockedUntil, walletVersion } from '$lib/rdd_getnetworkinfo_store';
	import type { ModalSettings, ToastSettings } from '@skeletonlabs/skeleton';
	import { getModalStore, getToastStore } from '@skeletonlabs/skeleton';
	import BlockchainInfo from '$lib/BlockchainInfo.svelte';
	import Toolbar from '$lib/components/Toolbar.svelte';
	import WalletVersion from '$lib/components/WalletVersion.svelte';

	const coin_name = 'ReddCoin';
	const modalStore = getModalStore();
	const toastStore = getToastStore();
	// const modal: ModalSettings = {
	// 	type: 'prompt',
	// 	// Data
	// 	title: 'Enter Password',
	// 	body: 'Provide your password to unlock your wallet',
	// 	// Populates the input value and attributes
	// 	value: '',
	// 	valueAttr: { type: 'password', minlength: 1, maxlength: 10, required: true },
	// 	// Returns the updated response value
	// 	response: (r: string) => console.log('response:', r),
	// };

	interface ModalSettings {
		type: 'prompt';
		title: string;
		body: string;
		response: (password: string) => void;
		valueAttr: { type: 'password'; minlength: 1; maxlength: 10; required: true };
	}

	async function walletUnlockFS() {
		const password = await new Promise<string>((resolve) => {
			const modal: ModalSettings = {
				type: 'prompt',
				title: 'Enter Password',
				body: `Please enter your password to unlock your ${coin_name} wallet:`,
				valueAttr: { type: 'password', minlength: 1, maxlength: 10, required: true },
				response: (password: string) => {
					resolve(password);
				}
			};
			modalStore.trigger(modal);
		});

		// Proceed with actions based on the response
		if (password) {
			console.log(`password sent: ${password}`);
			const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/reddcoin/api`, {
				method: 'POST',
				body: JSON.stringify({
					coin_type: CoinType.reddcoin,
					method_type: CoinMethodType.wallet_unlockfs,
					password: password
				})
			});

			wallet_unlockfs_response = await response.json();
			const json_result = JSON.stringify(wallet_unlockfs_response);
			console.log(`doPost json response: ${json_result}`);

			// const t: ToastSettings = {
			// 	message: 'This message will auto-hide after 10 seconds.',
			// 	timeout: 3000,
			// 	hideDismiss: true
			// };
			// toastStore.trigger(t);
		} else {
			console.log('Password not entered...');
		}
	}

	let block_height: number;
	let bw_api_response: BWAPIResponse;
	let coin_get_blockchain_info: GetBlockchainInfoResponse;
	let coin_get_network_info_response: GetNetworkInfoResponse;
	// let coin_api_response: CoinAPIResponse;
	let core_files_downloaded = false;
	let download_disabled = false;
	let getblockchaininfo_interval_id: ReturnType<typeof setInterval>;
	let getnetworkinfo_interval_id: ReturnType<typeof setInterval>;
	let is_ready_interval_id: ReturnType<typeof setInterval>;
	let is_working = false;
	let is_running = false;
	// let wallet_connections: number;
	let timer_get_blockchain_info_running = false;
	let timer_get_network_info_running = false;
	let wallet_offline: boolean;
	let wallet_unlocked_until: number;
	let wallet_unlockfs_response: GenericResponse;
	let wallet_verification_progress: number;
	let wallet_version: number;
	let daemon_is_ready: null | boolean = false;
	let daemon_is_running: null | boolean = false;

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

	const isReady = async () => {
		const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/reddcoin/api`, {
			method: 'POST',
			body: JSON.stringify({
				coin_type: CoinType.reddcoin,
				method_type: CoinMethodType.is_ready
			})
		});

		bw_api_response = await response.json();
		const json_result = JSON.stringify(bw_api_response);
		console.log(`isReady json response: ${json_result}`);
		daemon_is_ready = bw_api_response.is_ready;
		daemon_is_running = bw_api_response.is_running;
		if (bw_api_response.is_ready === true) {
			is_working = false;
			wallet_offline = false;
			clearInterval(is_ready_interval_id);
			if (!timer_get_network_info_running) {
				timer_get_network_info_running = true
				getnetworkinfo_interval_id = setInterval(async () => {
					await doGetNetworkInfoAPIRequest(CoinMethodType.get_network_info);
				}, 10000);
				await doGetNetworkInfoAPIRequest(CoinMethodType.get_network_info)
			}
		}
	};

	// async function doDownloadCoreFilesAPIRequest() {
	// 	// Confirm if core files are already downloaded.
	// 	let confirmed = false;
	// 	if (core_files_downloaded) {
	// 		await new Promise<boolean>((resolve) => {
	// 			const confirm_modal: ModalSettings = {
	// 				type: 'confirm',
	// 				title: 'Please Confirm',
	// 				body: `The ${coin_name} core files are already downloaded. Would you like to re-download them?`,
	// 				response: (r: boolean) => {
	// 					resolve(r);
	// 				}
	// 			};
	// 			modalStore.trigger(confirm_modal);
	// 		}).then((r: boolean) => {
	// 			confirmed = r;
	// 		});
	// 	}
	//
	// 	if (!confirmed && core_files_downloaded) {
	// 		return;
	// 	}
	//
	// 	download_disabled = true;
	// 	is_working = true;
	// 	const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/reddcoin/api`, {
	// 		method: 'POST',
	// 		body: JSON.stringify({
	// 			coin_type: CoinType.reddcoin,
	// 			method_type: CoinMethodType.download_core_files
	// 		})
	// 	});
	//
	// 	download_disabled = false;
	// 	is_working = false;
	//
	// 	const t: ToastSettings = {
	// 		message: `The ${coin_name} core files downloaded successfully.`,
	// 		timeout: 5000,
	// 		hideDismiss: true,
	// 		background: 'variant-filled-success'
	// 	};
	// 	toastStore.trigger(t);
	//
	// 	bw_api_response = await response.json();
	// 	if (bw_api_response.core_files_exists) {
	// 		core_files_downloaded = true;
	// 	}
	// }

	async function doGetBlockchainInfoAPIRequest(cmt: CoinMethodType) {
		const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/reddcoin/api`, {
			method: 'POST',
			body: JSON.stringify({
				coin_type: CoinType.reddcoin,
				method_type: cmt
			})
		});

		coin_get_blockchain_info = await response.json();
		const json_result = JSON.stringify(coin_get_blockchain_info);
		console.log(`doPost json response: ${json_result}`);
		block_height = coin_get_blockchain_info.result.blocks;
		headers.set(coin_get_blockchain_info.result.headers);
		blocks.set(coin_get_blockchain_info.result.blocks);
		difficulty.set(coin_get_blockchain_info.result.difficulty);
		// walletUnlockedUntil.set(coin_get_blockchain_info)

		wallet_verification_progress = coin_get_blockchain_info.result.verificationprogress;
	}

	async function doGetNetworkInfoAPIRequest(cmt: CoinMethodType) {
		const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/reddcoin/api`, {
			method: 'POST',
			body: JSON.stringify({
				coin_type: CoinType.reddcoin,
				method_type: cmt
			})
		});

		coin_get_network_info_response = await response.json();
		const json_result = JSON.stringify(coin_get_network_info_response);
		console.log(`doPost json response: ${json_result}`);
		walletConnections.set(coin_get_network_info_response.result.connections);
		walletVersion.set(coin_get_network_info_response.result.version);
		// wallet_unlocked_until = coin_get_network_info_response.result.unlocked_until;
		// walletUnlockedUntil.set(coin_get_network_info_response.result.unlocked_until);
		if (coin_get_network_info_response.result.connections > 0) {
			if (!timer_get_blockchain_info_running) {
				timer_get_blockchain_info_running = true;
				console.log('Setting GetBlockchainInfo timer');
				getblockchaininfo_interval_id = setInterval(async () => {
					await doGetBlockchainInfoAPIRequest(CoinMethodType.get_blockchain_info);
				}, 10000);
				await doGetBlockchainInfoAPIRequest(CoinMethodType.get_blockchain_info)
			}
		}
	}

	async function doGetCoreStatusAPIRequest(cmt: CoinMethodType) {
		const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/reddcoin/api`, {
			method: 'POST',
			body: JSON.stringify({
				coin_type: CoinType.reddcoin,
				method_type: cmt
			})
		});

		bw_api_response = await response.json();
		const json_result = JSON.stringify(bw_api_response);
		if (bw_api_response.is_running) {
			daemonRunningStatus.set(DaemonRunningStatusType.drst_running);
		}
		if (bw_api_response.core_files_exists) {
			core_files_downloaded = true;
			coreFileStatus.set(CoreFileStatusType.cfst_installed)
		}
		await isReady();
	}

	// async function doStartWalletAPIRequest(cmt: CoinMethodType) {
	// 	if (cmt === CoinMethodType.start_daemon) {
	// 		is_working = true;
	// 		is_ready_interval_id = setInterval(isReady, 2000);
	// 	}
	//
	// 	const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/reddcoin/api`, {
	// 		method: 'POST',
	// 		body: JSON.stringify({
	// 			coin_type: CoinType.reddcoin,
	// 			method_type: cmt
	// 		})
	// 	});
	//
	// 	bw_api_response = await response.json();
	// 	const json_result = JSON.stringify(
	// 		bw_api_response
	// 	);
	// 	console.log(`doPost json response: ${json_result}`);
	// 	console.log(`doPost is_running response: ${bw_api_response.is_running}`);
	// 	// daemon_is_ready = bw_api_response.is_ready;
	// 	// daemon_is_running = bw_api_response.is_running;
	// 	// if (bw_api_response.core_files_exists) {
	// 	// 	core_files_downloaded = true;
	// 	// }
	// }

	async function doStopWalletAPIRequest(cmt: CoinMethodType) {
		// Stop all timers
		clearInterval(getnetworkinfo_interval_id);
		clearInterval(getblockchaininfo_interval_id);
		const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/reddcoin/api`, {
			method: 'POST',
			body: JSON.stringify({
				coin_type: CoinType.reddcoin,
				method_type: cmt
			})
		});

		if (cmt === CoinMethodType.stop_daemon) {
			walletConnections.set(0);
			walletUnlockedUntil.set(-5);
			headers.set(0);
			blocks.set(0);
			difficulty.set(0);

			wallet_offline = true;
		}

		bw_api_response = await response.json();
		const json_result = JSON.stringify(bw_api_response);
		console.log(`doPost json response: ${json_result}`);
	}
</script>

<div class="container mx-auto p-8 space-y-4">
	<div class="flex flex-wrap items-center sm:space-x-5">
		<img src="../rdd_logo.png" alt="rdd_logo" class="mr-3 h-20" />
		<div>
		<h1 class="h1 pt-3 sm:pt-0">ReddCoin <span class="text-base inline-block"><WalletVersion/></span></h1>
		<h2 class="h2">The social currency</h2>
		</div>
	</div>
	<p>
		With over 60,000 users in 50+ countries, Redd allows you to share, tip, and donate to anyone,
		anywhere.
	</p>
	<section>
		<CoinStatus
			{block_height}
		/>
		<Toolbar
			{coin_name}
		/>
	</section>
<!--	<section>-->
<!--		<button-->
<!--			disabled={download_disabled}-->
<!--			class="btn variant-filled-tertiary"-->
<!--			type="button"-->
<!--			on:click={() => doDownloadCoreFilesAPIRequest()}-->
<!--		>-->
<!--			Download-->
<!--		</button>-->
<!--		<button-->
<!--			disabled={is_running || !core_files_downloaded}-->
<!--			class="btn variant-filled-tertiary"-->
<!--			type="button"-->
<!--			on:click={() => doStartWalletAPIRequest(CoinMethodType.start_daemon)}-->
<!--		>-->
<!--			Start-->
<!--		</button>-->

<!--		<button-->
<!--			class="btn variant-filled-tertiary"-->
<!--			disabled={!is_running}-->
<!--			type="button"-->
<!--			on:click={walletUnlockFS}-->
<!--		>-->
<!--			Unlock for staking-->
<!--		</button>-->

<!--		<button-->
<!--			class="btn variant-filled-tertiary"-->
<!--			disabled={!is_running}-->
<!--			type="button"-->
<!--			on:click={() => doStopWalletAPIRequest(CoinMethodType.stop_daemon)}-->
<!--		>-->
<!--			Stop-->
<!--		</button>-->
<!--	</section>-->
	<section>
		<BlockchainInfo />
		<!--		<BlockchainHeaders/>-->
		<!--		<BlockchainBlocks/>-->
	</section>
</div>
