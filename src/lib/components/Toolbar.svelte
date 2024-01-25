<script lang="ts">
	import { createToolbar, melt } from '@melt-ui/svelte';

	// Icons
	import { Download, Play, StopCircle, Unlock } from 'lucide-svelte';
	import { coreFileStatus, walletRunningStatus } from '$lib/bw_store';
	import {
		type BWAPIResponse,
		CoinMethodType,
		CoinType,
		CoreFileStatusType,
		type WalletRunningStatusType
	} from '$lib/bwtypes';
	import { PUBLIC_HOST_IP } from '$env/static/public';
	import { getModalStore, getToastStore, type ToastSettings } from '@skeletonlabs/skeleton';

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

	let core_files_status: CoreFileStatusType;
	const unsub_core_file_status = coreFileStatus.subscribe((value) => {
		core_files_status = value;
	});

	let wallet_running_status: WalletRunningStatusType;
	const unsub_wallet_running_status = walletRunningStatus.subscribe((value) => {
		wallet_running_status = value;
	});

	let disable_download_button = false

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
		coreFileStatus.set(CoreFileStatusType.cfst_downloading);
		const response = await fetch(`http://${PUBLIC_HOST_IP}:5173/coins/reddcoin/api`, {
			method: 'POST',
			body: JSON.stringify({
				coin_type: CoinType.reddcoin,
				method_type: CoinMethodType.download_core_files
			})
		});

		disable_download_button = false

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
		<button class="item" aria-label="start" use:melt={$button}>
			<Play class="square-5" />
		</button>
		<button class="item" aria-label="stop" use:melt={$button}>
			<StopCircle class="square-5" />
		</button>
		<div class="separator" use:melt={$separator} />
		<button class="item" aria-label="unlock" use:melt={$button}>
			<Unlock class="square-5" />
		</button>
	</div>
	<div class="separator" use:melt={$separator} />
	<!--	<a href="/" class="link nowrap flex-shrink-0" use:melt={$link}> Edited 2 hours ago </a>-->
	<button
		class="ml-auto rounded-md bg-green-600 px-3 py-1 font-medium text-magnum-100 hover:opacity-75 active:opacity-50"
		use:melt={$button}>Save</button
	>
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
