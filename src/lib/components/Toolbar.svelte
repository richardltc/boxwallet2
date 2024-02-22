<script lang="ts">
	import { createToolbar, melt } from '@melt-ui/svelte';

	// Icons
	import { Download, Play, StopCircle, Unlock } from 'lucide-svelte';
	import { coreFileStatus, daemonRunningStatus, isWorking } from '$lib/bw_store';
	import {
		type BWAPIResponse,
		CoinMethodType,
		CoinType,
		CoreFileStatusType,
		DaemonRunningStatusType
	} from '$lib/bwtypes';
	import { PUBLIC_HOST_IP } from '$env/static/public';
	import { getModalStore, getToastStore, type ToastSettings } from '@skeletonlabs/skeleton';
	import { walletConnections, walletUnlockedUntil, walletVersion } from '$lib/rdd_getnetworkinfo_store';
	import type { GetBlockchainInfoResponse, GetNetworkInfoResponse } from '$lib/rdd_types';
	import { blocks, difficulty, headers, verificationProgress } from '$lib/rdd_getblockchaininfo_store';

	export let coin_name: string;

	const modalStore = getModalStore();
	const toastStore = getToastStore();

	const {
		elements: { root, button, separator },
		builders: { createToolbarGroup }
	} = createToolbar();
	const {
		elements: { group: fontGroup, item: fontItem }
	} = createToolbarGroup({
		type: 'multiple'
	});
	const {
		elements: { group: alignGroup, item: alignItem }
	} = createToolbarGroup();

	interface ModalSettings {
		type: 'prompt';
		title: string;
		body: string;
		response: (password: string) => void;
		valueAttr: { type: 'password'; minlength: 1; maxlength: 10; required: true };
	}

	let bw_api_response: BWAPIResponse;
	let coin_get_blockchain_info: GetBlockchainInfoResponse;
	let coin_get_network_info_response: GetNetworkInfoResponse;
	let core_files_status: CoreFileStatusType;
	let daemon_is_ready: null | boolean = false;
	let daemon_is_running: null | boolean = false;
	let disable_download_button = false;
	let getblockchaininfo_interval_id: ReturnType<typeof setInterval>;
	let getnetworkinfo_interval_id: ReturnType<typeof setInterval>;
	let is_ready_interval_id: ReturnType<typeof setInterval>;
	let timer_get_blockchain_info_running = false;
	let timer_get_network_info_running = false;
	let daemon_running_status: DaemonRunningStatusType;

	const unsub_core_file_status = coreFileStatus.subscribe((value) => {
		core_files_status = value;
	});
	const unsub_daemon_running_status = daemonRunningStatus.subscribe((value) => {
		daemon_running_status = value;
	});

	// const unsub_wallet_running_status = walletRunningStatus.subscribe((value) => {
	// 	wallet_running_status = value;
	// });

	/////////////////////////////////
	// Download
	async function doDownloadCoreFilesAPIRequest() {
		// Confirm if core files are already downloaded.
		let confirmed = false;
		if (core_files_status === CoreFileStatusType.cfst_installed) {
			await new Promise<boolean>((resolve) => {
				const confirm_modal: ModalSettings = {
					type: 'confirm',
					title: 'Please Confirm',
					body: `The ${coin_name} core files are already downloaded. Would you like to re-download them?`,
					response: (r: boolean) => {
						resolve(r);
					}
				};
				modalStore.trigger(confirm_modal);
			}).then((r: boolean) => {
				confirmed = r;
			});
		}

		if (!confirmed && core_files_status === CoreFileStatusType.cfst_installed) {
			return;
		}

		disable_download_button = true;
		isWorking.set(true);
		coreFileStatus.set(CoreFileStatusType.cfst_downloading);
		const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/reddcoin/api`, {
			method: 'POST',
			body: JSON.stringify({
				coin_type: CoinType.reddcoin,
				method_type: CoinMethodType.download_core_files
			})
		});

		disable_download_button = false;
		isWorking.set(false);

		const t: ToastSettings = {
			message: `The ${coin_name} core files downloaded successfully.`,
			timeout: 5000,
			hideDismiss: true,
			background: 'variant-filled-success'
		};
		toastStore.trigger(t);

		bw_api_response = await response.json();
		if (bw_api_response.core_files_exists) {
			coreFileStatus.set(CoreFileStatusType.cfst_installed);
		}
	}

	/////////////////////////////////
	// Get Blockchain Info
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
		// block_height = coin_get_blockchain_info.result.blocks;
		headers.set(coin_get_blockchain_info.result.headers);
		blocks.set(coin_get_blockchain_info.result.blocks);
		difficulty.set(coin_get_blockchain_info.result.difficulty);
		// walletUnlockedUntil.set(coin_get_blockchain_info)

		verificationProgress.set(coin_get_blockchain_info.result.verificationprogress);
	}

	/////////////////////////////////
	// Get Network Info
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
				await doGetBlockchainInfoAPIRequest(CoinMethodType.get_blockchain_info);
			}
		}
	}

	/////////////////////////////////
	// Start Wallet
	async function doStartWalletAPIRequest() {
		isWorking.set(true);
		is_ready_interval_id = setInterval(isReady, 2000);
		daemonRunningStatus.set(DaemonRunningStatusType.drst_starting);

		const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/reddcoin/api`, {
			method: 'POST',
			body: JSON.stringify({
				coin_type: CoinType.reddcoin,
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

	/////////////////////////////////
	// Is Ready
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
			isWorking.set(false);
			daemonRunningStatus.set(DaemonRunningStatusType.drst_running)
			// walletRunningStatus.set(WalletRunningStatusType.wrst_stopped);
			clearInterval(is_ready_interval_id);
			if (!timer_get_network_info_running) {
				timer_get_network_info_running = true;
				getnetworkinfo_interval_id = setInterval(async () => {
					await doGetNetworkInfoAPIRequest(CoinMethodType.get_network_info);
				}, 10000);
				await doGetNetworkInfoAPIRequest(CoinMethodType.get_network_info);
			}
		}
	};

	/////////////////////////////////
	// Stop Wallet
	async function doStopWalletAPIRequest() {
		// Stop all timers
		clearInterval(getnetworkinfo_interval_id);
		clearInterval(getblockchaininfo_interval_id);
		const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/reddcoin/api`, {
			method: 'POST',
			body: JSON.stringify({
				coin_type: CoinType.reddcoin,
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
		console.log(`doPost json response: ${json_result}`);
	}
</script>

<div
	use:melt={$root}
	class="flex min-w-max items-center gap-4 rounded-md bg-white px-3 py-2 text-neutral-700 shadow-sm lg:w-[35rem]"
>
	<div class="flex items-center gap-1 hover:opacity-95" use:melt={$fontGroup}>
		{#if core_files_status === CoreFileStatusType.cfst_installed}
			<button
				class="item"
				aria-label="upgrade"
				disabled={disable_download_button}
				title="Upgrade core wallet files"
				on:click={() => doDownloadCoreFilesAPIRequest()}
				use:melt={$button}
			>
				<Download class="square-5" />
			</button>
		{:else}
			<button
				class="item"
				disabled={disable_download_button}
				aria-label="download"
				title="Download core wallet files"
				on:click={() => doDownloadCoreFilesAPIRequest()}
				use:melt={$button}
			>
				<Download class="square-5" />
			</button>
		{/if}
		{#if daemon_running_status === DaemonRunningStatusType.drst_stopped}
			<button
				class="item"
				disabled={false}
				aria-label="start"
				title="Start {coin_name} wallet"
				on:click={() => doStartWalletAPIRequest()}
				use:melt={$button}
			>
				<Play class="square-5" />
			</button>
		{:else}
			<button
				class="item"
				disabled={true}
				aria-label="start"
				title="Start {coin_name} wallet"
				on:click={() => doStartWalletAPIRequest()}
				use:melt={$button}
			>
				<Play class="square-5" />
			</button>
		{/if}
		{#if daemon_running_status === DaemonRunningStatusType.drst_running}
		<button
			class="item"
			disabled={false}
			aria-label="stop"
			on:click={() => doStopWalletAPIRequest()}
			title="Stop {coin_name} wallet"
			use:melt={$button}
		>
			<StopCircle class="square-5" />
		</button>
			{:else}
			<button
				class="item"
				disabled={true}
				aria-label="stop"
				on:click={() => doStopWalletAPIRequest()}
				title="Stop {coin_name} wallet"
				use:melt={$button}
			>
				<StopCircle class="square-5" />
			</button>
			{/if}
		<div class="separator" use:melt={$separator} />
		<button class="item" aria-label="unlock" use:melt={$button}>
			<Unlock class="square-5" />
		</button>
	</div>
	<div class="separator" use:melt={$separator} />
	<!--	<a href="/" class="link nowrap flex-shrink-0" use:melt={$link}> Edited 2 hours ago </a>-->
<!--	<button-->
<!--		class="ml-auto rounded-md bg-green-600 px-3 py-1 font-medium text-magnum-100 hover:opacity-75 active:opacity-50"-->
<!--		use:melt={$button}>Save</button-->
<!--	>-->
</div>

<style lang="postcss">
	.item {
		padding: theme('spacing.1');
		border-radius: theme('borderRadius.md');

		&:hover {
			background-color: theme('colors.green.200');
		}

		&[data-state='on'] {
			background-color: theme('colors.green.300');
			color: theme('colors.green.900');
		}
		&:disabled {
			/* Apply styles for disabled state: */
			opacity: 0.5; /* Reduce opacity for visual cue */
			cursor: not-allowed; /* Change cursor to indicate disabled state */
			/*background-color: theme('colors.neutral.400'); !* Use a neutral gray background *!*/
			/*color: theme('colors.neutral.600'); !* Adjust text color for better contrast *!*/
		}
		&:focus {
			@apply ring-2 ring-green-400;
		}
	}

	.separator {
		width: 1px;
		background-color: theme('colors.neutral.300');
		align-self: stretch;
	}
</style>
