<script lang="ts">
	import { createToolbar, melt } from '@melt-ui/svelte';

	// Icons
	import { Download, Play, StopCircle, Unlock } from 'lucide-svelte';
	import { isWorking } from '$lib/bw_store';
	import {
		type BWAPIResponse,
		CoinMethodType,
		CoinType,
		CoreFileStatusType,
		DaemonRunningStatusType
	} from '$lib/bw_types';
	import { PUBLIC_HOST_IP } from '$env/static/public';
	import { getModalStore, getToastStore, type ToastSettings } from '@skeletonlabs/skeleton';
	import { walletConnections, walletUnlockedUntil, coinWalletVersion } from '$lib/rdd/rdd_getnetworkinfo_store';
	import type { GetBlockchainInfoResponse, GetNetworkInfoResponse } from '$lib/rdd/rdd_types';
	import type { CoinData, CoinClientAdapter } from '$lib/coin_types';
	import type { GenericResponse } from '$lib/divi/divi_types';

	// export let coinData: CoinData;
	export let clientAdapter: CoinClientAdapter
	export let coin_name: string;
	export let coin_name_api: string;
	export let core_files_status: CoreFileStatusType;
	export let daemon_running_status: DaemonRunningStatusType;
	export let wallet_unlocked_until = -5;

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
	// let core_files_status: CoreFileStatusType;
	let daemon_is_ready: null | boolean = false;
	let daemon_is_running: null | boolean = false;
	let disable_download_button = false;
	let getblockchaininfo_interval_id: ReturnType<typeof setInterval>;
	let getnetworkinfo_interval_id: ReturnType<typeof setInterval>;
	let is_ready_interval_id: ReturnType<typeof setInterval>;
	let timer_get_blockchain_info_running = false;
	let timer_get_network_info_running = false;
	let wallet_unlockfs_response: GenericResponse;
	// let daemon_running_status: DaemonRunningStatusType;

	// const unsub_core_file_status = coreFileStatus.subscribe((value) => {
	// 	core_files_status = value;
	// });
	// const unsub_daemon_running_status = daemonRunningStatus.subscribe((value) => {
	// 	daemon_running_status = value;
	// });

	/////////////////////////////////
	// Download
	async function downloadCoreFilesAPIRequest() {
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
		// coreFileStatus.set(CoreFileStatusType.cfst_downloading);
		core_files_status = CoreFileStatusType.cfst_downloading;
		const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/${coin_name_api}/api`, {
			method: 'POST',
			body: JSON.stringify({
				// coin_type: CoinType.reddcoin,
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
			core_files_status = CoreFileStatusType.cfst_installed;
		}
	}

	async function startDaemon() {
		await clientAdapter.startDaemon();
	}
	async function stopDaemon() {
		await clientAdapter.stopDaemon();
	}

	/////////////////////////////////
	// Unlock Wallet for Staking
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
			const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/${coin_name_api}/api`, {
				method: 'POST',
				body: JSON.stringify({
					coin_type: CoinType.reddcoin,
					method_type: CoinMethodType.wallet_unlockfs,
					password: password
				})
			});

			wallet_unlockfs_response = await response.json();
			const json_result = JSON.stringify(wallet_unlockfs_response);
			console.log(`unlock wallet response: ${json_result}`);
			// If the wallet response is anything other than what it would be for a correct password then...
			if (!json_result.includes('"result":null,"error":null,"id"')) {
				const t: ToastSettings = {
					message: `Failed to unlock your ${coin_name} wallet!`,
					timeout: 5000,
					hideDismiss: true,
					background: 'variant-filled-error'
				};
				toastStore.trigger(t);
				console.log('Incorrect passphrase detected...');
			} else {
				// We're good, so let the user know! :)
				const t: ToastSettings = {
					message: `Your ${coin_name} wallet has been unlocked for staking.`,
					timeout: 5000,
					hideDismiss: true,
					background: 'variant-filled-success'
				};
				toastStore.trigger(t);
			}
		} else {
			console.log('Password not entered...');
		}
	}
</script>

<div
	use:melt={$root}
	class="flex min-w-max items-center gap-4 rounded-md bg-white px-3 py-1 text-neutral-700 shadow-sm lg:w-[35rem]"
>
	<div class="flex items-center gap-1 hover:opacity-95" use:melt={$fontGroup}>
    <!--	DOWNLOAD Button	-->
		{#if core_files_status === CoreFileStatusType.cfst_installed}
			<button
				class="item"
				aria-label="upgrade"
				disabled={disable_download_button}
				title='Upgrade {coin_name} core wallet files'
				on:click={() => downloadCoreFilesAPIRequest()}
				use:melt={$button}
			>
				<Download class="square-5" />
			</button>
		{:else}
			<button
				class="item"
				disabled={disable_download_button}
				aria-label="download"
				title='Download {coin_name} core wallet files'
				on:click={() => downloadCoreFilesAPIRequest()}
				use:melt={$button}
			>
				<Download class="square-5" />
			</button>
		{/if}

		<div class="separator" use:melt={$separator} />

		<!--	START Button	-->
		{#if (daemon_running_status === DaemonRunningStatusType.drst_stopped) && (core_files_status === CoreFileStatusType.cfst_installed)}
			<button
				class="item"
				disabled={false}
				aria-label="start"
				title="Start {coin_name} wallet"
				on:click={() => startDaemon()}
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
				on:click={() => startDaemon()}
				use:melt={$button}
			>
				<Play class="square-5" />
			</button>
		{/if}

		<!--	STOP Button	-->
		{#if daemon_running_status === DaemonRunningStatusType.drst_running}
		<button
			class="item"
			disabled={false}
			aria-label="stop"
			on:click={() => stopDaemon()}
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
				on:click={() => stopDaemon()}
				title="Stop {coin_name} wallet"
				use:melt={$button}
			>
				<StopCircle class="square-5" />
			</button>
			{/if}

		<div class="separator" use:melt={$separator} />

		{#if wallet_unlocked_until === 0}
			<button
				class="item"
				disabled={false}
				aria-label="unlock"
				title="Unlock {coin_name} wallet"
				on:click={() => walletUnlockFS()}
				use:melt={$button}
			>
				<Unlock class="square-5" />
			</button>
		{:else if wallet_unlocked_until - 1}
			<button
				class="item"
				disabled={false}
				aria-label="lock"
				title="Lock {coin_name} wallet"
				use:melt={$button}
			>
				<Unlock class="square-5" />
			</button>
		{:else if wallet_unlocked_until > 0}
			<button
				class="item"
				disabled={false}
				aria-label="lock"
				title="Lock {coin_name} wallet"
				use:melt={$button}
			>
				<Unlock class="square-5" />
			</button>
		{:else}
			<button
				class="item"
				disabled={true}
				aria-label="unlock"
				title="Unlock {coin_name} wallet"
				use:melt={$button}
			>
				<Unlock class="square-5" />
			</button>
		{/if}
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
			@apply ring-2 ring-box_wallet-100;
		}
	}

	.separator {
		width: 1px;
		background-color: theme('colors.neutral.300');
		align-self: stretch;
	}
</style>
