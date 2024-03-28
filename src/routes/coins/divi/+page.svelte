<script lang="ts">
	import {
		type BWAPIResponse,
		CoinMethodType,
		CoinType, CoreFileStatusType,
		DaemonRunningStatusType
	} from '$lib/bw_types';
	import CoinStatus from '$lib/CoinStatus.svelte';
	import { PUBLIC_HOST_IP } from '$env/static/public';
	import { onMount } from 'svelte';
	import * as divi_client from '$lib/divi/divi_client';
	import type { GenericResponse, GetBlockchainInfoResponse, GetNetworkInfoResponse } from '$lib/divi/divi_types.js';
	import { verificationProgress, blocks, difficulty, headers } from '$lib/divi/divi_getblockchaininfo_store';
	import { coreFileStatus, daemonRunningStatus } from '$lib/divi/divi_core_status_store';
	// import { walletConnections, walletUnlockedUntil, walletVersion } from '$lib/divi/divi_getnetworkinfo_store';
	import type { ModalSettings, ToastSettings } from '@skeletonlabs/skeleton';
	import { getModalStore, getToastStore } from '@skeletonlabs/skeleton';
	import BlockchainInfo from '$lib/BlockchainInfo.svelte';
	import Toolbar from '$lib/components/Toolbar.svelte';
	import WalletVersion from '$lib/components/WalletVersion.svelte';
	import {DIVIClientAdapter} from '$lib/divi/divi_client_adapter'
	import type { CoinClientAdapter } from '$lib/coin_types';
	import { coinWalletVersion, walletConnections} from '$lib/divi/divi_getnetworkinfo_store';
	import { walletUnlockedUntil } from '$lib/divi/divi_getwalletinfo_store';

	let blocks_height = 0;
	let coin_wallet_version = "";
	let core_files_status: CoreFileStatusType;
	let daemon_running_status: DaemonRunningStatusType;
	let difficulty_value =0;
	let headers_height = 0;
	let verification_progress = 0;
	let wallet_connections = 0;
	let wallet_unlocked_until = -5;

	const unsub_blocks = blocks.subscribe((value) => {
		blocks_height = value;
	});
	const unsub_coinWalletVersion = coinWalletVersion.subscribe((value) => {
		coin_wallet_version = value;
	});
	const unsub_coreFileStatus = coreFileStatus.subscribe((value) => {
		core_files_status = value;
	});
	const unsub_daemonRunningStatus = daemonRunningStatus.subscribe((value) => {
		daemon_running_status = value;
	});
	const unsub_difficulty = difficulty.subscribe((value) => {
		difficulty_value = value;
	});
	const unsub_headers = headers.subscribe((value) => {
		headers_height = value;
	});
	const unsub_verficationPrgress = verificationProgress.subscribe((value) => {
		verification_progress = value;
	});
	const unsub_walletConnections = walletConnections.subscribe((value) => {
		wallet_connections = value;
	});
	const unsub_walletUnlockUntil = walletUnlockedUntil.subscribe((value) => {
		wallet_unlocked_until = value;
		console.log(`page.svelte - wallet_unlocked until: ${wallet_unlocked_until}`)
	});

	const coinClientAdapter = new DIVIClientAdapter;

	const coin_colour_primary = '#ed2c57';
	const coin_colour_secondary = '#ed2c57';
	const coin_colour_thirdly = '#ed2c57';
	const coin_colour_fourthly = '#ed2c57';

	const coin_logo = '../divi_logo.png';
	const coin_alt_logo = '../divi_logo';
	const coin_name = 'Divi';
	const coin_name_api = 'divi';
	const coin_subtitle = 'Crypto Made Easy'
	const coin_description = 'The foundation for a truly decentralized future. Our rapidly changing world requires flexible financial products. Through our innovative technology, we’re building the future of finance.'

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

	let coin_get_blockchain_info: GetBlockchainInfoResponse;
	let coin_get_network_info_response: GetNetworkInfoResponse;
	// let coin_api_response: CoinAPIResponse;
	let core_files_downloaded = false;
	let download_disabled = false;
	let getblockchaininfo_interval_id: ReturnType<typeof setInterval>;
	let getnetworkinfo_interval_id: ReturnType<typeof setInterval>;
	let is_ready_interval_id: ReturnType<typeof setInterval>;
	let is_ready = false;
	let is_working = false;
	let is_running = false;
	// let wallet_connections: number;
	let timer_get_blockchain_info_running = false;
	let timer_get_network_info_running = false;
	let wallet_offline: boolean;
	let wallet_unlockfs_response: GenericResponse;
	let wallet_verification_progress: number;
	let wallet_version: number;
	let daemon_is_ready: null | boolean = false;
	let daemon_is_running: null | boolean = false;

	onMount(async () => {
		// is_ready_interval_id = setInterval(async () => {
		// 	await rdd_client.IsReady();
		// }, 10000);

		await divi_client.GetCoreStatusAPIRequest(CoinMethodType.get_core_status);
	  await divi_client.IsReady();
	});

</script>

<div class="container mx-auto p-8 space-y-4">
	<div class="flex flex-wrap items-center sm:space-x-5">
		<div class="flex items-center flex-grow">
			<img src="{coin_logo}" alt="{coin_alt_logo}" class="mr-3 h-20" />
			<div>
				<h1 class="h1 pt-3 sm:pt-0">{coin_name} <span class="text-base inline-block">
        <WalletVersion wallet_version={coin_wallet_version}/></span></h1>
				<h2 class="h2">{coin_subtitle}</h2>
			</div>
		</div>
		<div class="ml-auto">
			<CoinStatus
				coin_colour_primary={coin_colour_primary}
				coin_colour_secondary={coin_colour_secondary}
				coin_colour_thirdly={coin_colour_thirdly}
				coin_colour_fourthly={coin_colour_fourthly}
				core_files_status={core_files_status}
				block_height={blocks_height}
				daemon_running_status={daemon_running_status}
				wallet_verification_progress={verification_progress}
				wallet_connections={wallet_connections}
				wallet_unlocked_until={wallet_unlocked_until}
			/>
		</div>
	</div>
	<p>
		{coin_description}
	</p>
	<section>

		<Toolbar
			clientAdapter={coinClientAdapter}
			coin_name={coin_name}
			coin_name_api={coin_name_api}
			bind:core_files_status={core_files_status}
			daemon_running_status={daemon_running_status}
			wallet_unlocked_until={wallet_unlocked_until}
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
		<BlockchainInfo
			blocks={blocks_height}
			difficulty={difficulty_value}
		  headers={headers_height}
		/>
		<!--		<BlockchainHeaders/>-->
		<!--		<BlockchainBlocks/>-->
	</section>
</div>
