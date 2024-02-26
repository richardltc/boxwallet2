<script lang="ts">
	import { CoreFileStatusType, DaemonRunningStatusType, IconStatusType } from '$lib/bwtypes';
	import { coreFileStatus, daemonRunningStatus, isWorking } from '$lib/bw_store';
	import { verificationProgress } from '$lib/rdd_getblockchaininfo_store';
	import { walletUnlockedUntil, walletConnections } from '$lib/rdd_getnetworkinfo_store';

	export let block_height: number;

	let core_file_status: CoreFileStatusType;
	let daemon_running_status: DaemonRunningStatusType;
	let icon_wallet_security_class = '';
	let icon_wallet_security_title = '';
	let wallet_verification_progress: number;
	// export let wallet_offline = true;
	let icon_is_ready_class = '';
	let icon_is_ready_title = '';
	let icon_wallet_connections_class = '';
	let icon_wallet_connections_title = '';
	let icon_is_staking_class = '';
	let icon_is_staking_title = '';
	let icon_is_syncing_class = '';
	let icon_is_syncing_title = '';
	let icon_is_working_class = '';
	let icon_is_working_title = '';
	let icon_core_files_downloaded_class = '';
	let icon_core_files_downloaded_title = '';

	let is_working = false;
	const unsub_core_file_status = coreFileStatus.subscribe((value) => {
		core_file_status = value;
	});
	const unsub_daemon_running_status = daemonRunningStatus.subscribe((value) => {
		daemon_running_status = value;
	});

	const unsub_is_working = isWorking.subscribe((value) => {
		is_working = value;
	});

	let wallet_connections: number;
	const unsub_wallet_connections = walletConnections.subscribe((value) => {
		wallet_connections = value;

		// if (wallet_connections > 0) {
		// 	icon_wallet_connections_title = `${wallet_connections} connections`;
		// 	icon_wallet_connections_class = 'fa-solid fa-network-wired fa-2x';
		// } else {
		// 	icon_wallet_connections_title = 'Not connected';
		// 	icon_wallet_connections_class = 'fa-solid fa-network-wired fa-2x disabled-icon';
		// }
	});

	const unsub_wallet_verification_progress = verificationProgress.subscribe((value) => {
		wallet_verification_progress = value;
	});

	let unlocked_until_value: number;
	const unsubscribe = walletUnlockedUntil.subscribe((value) => {
		unlocked_until_value = value;

		if (unlocked_until_value === -5) {
			icon_wallet_security_class = 'fa-solid fa-lock-open fa-2x disabled-icon';
			icon_wallet_security_title = 'Offline';
		} else if (unlocked_until_value === 0) {
			icon_wallet_security_class = 'fa-solid fa-lock fa-2x';
			icon_wallet_security_title = 'Wallet locked';
			console.log('wallet status locked');
		} else if (unlocked_until_value === -1) {
			icon_wallet_security_class = 'fa-solid fa-lock-open fa-2x';
			icon_wallet_security_title = 'Wallet unlocked';
			console.log('wallet status unlocked');
		} else if (unlocked_until_value > 0) {
			icon_wallet_security_class = 'fa-solid fa-lock fa-2x';
			icon_wallet_security_title = 'Wallet unlocked for staking.';
			console.log('wallet status unlocked for staking');
		}
	});

	// function convertBCVerification(verificationPG: number): string {
	//     let sProg: string;
	//     let fProg: number;
	//
	//     fProg = verificationPG * 100;
	//     sProg = fProg.toFixed(2);
	//
	//     if (sProg === "100.00") {
	//         sProg = "99.99";
	//     }
	//
	//     return `${sProg}%`;
	// }

	// $: {
	// 	if (wallet_offline) {
	// 		icon_is_ready_class = 'fa-solid fa-face-smile fa-2x disabled-icon';
	// 		icon_is_ready_title = 'Offline';
	// 		icon_is_staking_class = 'fa-solid fa-microchip fa-2x fa-spin-stop disabled-icon';
	// 		icon_is_staking_title = 'Offline';
	// 		icon_is_syncing_class = 'fa-solid fa-rotate fa-2x fa-spin-stop disabled-icon';
	// 		icon_is_syncing_title = 'Offline';
	// 		// icon_wallet_connections_title = "Offline"
	// 		// icon_wallet_connections_class = "fa-solid fa-network-wired fa-2x disabled-icon"
	// 		// icon_wallet_security_class = "fa-solid fa-lock-open fa-2x disabled-icon"
	// 		// icon_wallet_security_title = "Offline"
	// 	} else {
	// 		if (is_ready) {
	// 			icon_is_ready_class = 'fa-solid fa-face-smile fa-2x';
	// 			icon_is_ready_title = 'Core wallet is ready.';
	// 		} else {
	// 			icon_is_ready_class = 'fa-solid fa-face-smile fa-2x disabled-icon';
	// 			icon_is_ready_title = 'Core wallet is not ready.';
	// 		}
	// 		if (wallet_verification_progress < 0.99999 && wallet_connections > 0) {
	// 			icon_is_syncing_class = 'fa-solid fa-rotate fa-2x fa-spin';
	// 			icon_is_syncing_title = `Blockchain is syncing... Blocks: ${block_height}`;
	// 		} else if (wallet_connections > 0) {
	// 			icon_is_syncing_class = 'fa-solid fa-rotate fa-2x fa-spin-stop';
	// 			icon_is_syncing_title = `Blockchain is synced. Blocks: ${block_height}`;
	// 		}
	// 	}

	// if (is_working) {
	//     icon_is_working_class = "fa-solid fa-cog fa-spin fa-2x";
	//     icon_is_working_title = "Working..."
	// } else {
	//     icon_is_working_class = "fa-solid fa-cog fa-2x fa-spin-stop"
	//     icon_is_working_title = "Idle"
	// }
	// if (core_files_downloaded) {
	// 	icon_core_files_downloaded_class = 'fa-solid fa-download fa-2x';
	// 	icon_core_files_downloaded_title = 'Core files have been downloaded';
	// } else {
	// 	icon_core_files_downloaded_class = 'fa-solid fa-download fa-2x disabled-icon';
	// 	icon_core_files_downloaded_title = 'Core files need to be downloaded';
	// }
	// }
</script>

<main>
	<div class="flex flex-wrap -mx-2 items-start">
		<!--		Working-->
		{#if is_working}
			<div class="px-2 py-2">
				<span title="Working..."><i class="fa-solid fa-cog fa-spin fa-2x" /></span>
			</div>
		{:else}
			<div class="px-2 py-2">
				<span title="Idle"><i class="fa-solid fa-cog fa-2x fa-spin-stop" /></span>
			</div>
		{/if}

		<!--		Core file status-->
		{#if core_file_status === CoreFileStatusType.cfst_installed}
			<div class="px-2 py-2">
				<span title="Core files have been downloaded"><i class="fa-solid fa-download fa-2x" /></span
				>
			</div>
		{:else}
			<div class="px-2 py-2">
				<span title="Core files need to be downloaded"
					><i class="fa-solid fa-download fa-2x disabled-icon" /></span
				>
			</div>
		{/if}

		<!--		Daemon is running-->
		{#if daemon_running_status === DaemonRunningStatusType.drst_running}
			<div class="px-2 py-2">
				<span title="Core wallet is ready."><i class="fa-solid fa-face-smile fa-2x" /></span>
			</div>
		{:else}
			<div class="px-2 py-2">
				<span title="Core wallet is not ready."
					><i class="fa-solid fa-face-smile fa-2x disabled-icon" /></span
				>
			</div>
		{/if}

		<!--		Wallet connections-->
		{#if wallet_connections > 0}
			<div class="px-2 py-2">
				<span title="${wallet_connections} connections"
					><i class="fa-solid fa-network-wired fa-2x" /></span
				>
			</div>
		{:else}
			<div class="px-2 py-2">
				<span title="Not connected"
					><i class="fa-solid fa-network-wired fa-2x disabled-icon" /></span
				>
			</div>
		{/if}

		{#if (wallet_verification_progress < 0.99999) && (wallet_connections > 0)}
			<div class="px-2 py-2">
				<span title="Blockchain is syncing... Blocks: ${block_height}"
					><i class="fa-solid fa-rotate fa-2x fa-spin" /></span
				>
			</div>
		{:else if wallet_connections > 0}
			<div class="px-2 py-2">
				<span title="Blockchain is synced. Blocks: ${block_height}"
					><i class="fa-solid fa-rotate fa-2x fa-spin-stop" /></span
				>
			</div>
		{:else}
			<div class="px-2 py-2">
				<span title="Offline"
					><i class="fa-solid fa-rotate fa-2x fa-spin-stop disabled-icon" /></span
				>
			</div>
		{/if}

		<div class="px-2 py-2">
			<span title="Offline"><i class="fa-solid fa-lock-open fa-2x disabled-icon" /></span>
		</div>
		<div class="px-2 py-2">
			<span title="Offline"
				><i class="fa-solid fa-microchip fa-2x fa-spin-stop disabled-icon" /></span
			>
		</div>
	</div>
</main>

<style>
	.disabled-icon {
		pointer-events: none;
		color: #999; /* You can adjust the color to make it visually disabled */
		opacity: 0.5; /* You can adjust the opacity as well */
	}

	i {
		padding-right: 0;
	}

	.wrapper {
		display: flex;
	}

	.flex-item {
		margin: 0 15px 0 0;
	}
</style>
