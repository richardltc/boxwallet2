<script lang="ts">
	import { CoreFileStatusType, DaemonRunningStatusType, IconStatusType } from '$lib/bw_types';
	import { isWorking } from '$lib/bw_store';
	import { verificationProgress } from '$lib/rdd/rdd_getblockchaininfo_store';
	import { walletUnlockedUntil, walletConnections } from '$lib/rdd/rdd_getnetworkinfo_store';

	export let block_height: number;
	export let coin_colour_primary: string;
	export let coin_colour_secondary: string;
	export let coin_colour_thirdly: string;
	export let coin_colour_fourthly: string;
	export let core_files_status: CoreFileStatusType;
	export let daemon_running_status: DaemonRunningStatusType;
	export let wallet_connections: number;
	export let wallet_verification_progress: number;
	export let wallet_unlocked_until = -5;

	import { setContext } from 'svelte';

	setContext('--coin-colour-primary', coin_colour_primary); // Set the context with the coinColor prop

	// let daemon_running_status: DaemonRunningStatusType;
	// export let wallet_offline = true;
	let icon_wallet_connections_class = '';
	let icon_wallet_connections_title = '';
	let icon_wallet_security_class = '';
	let icon_wallet_security_title = '';

	let icon_is_staking_class = '';
	let icon_is_staking_title = '';
	let icon_is_syncing_class = '';
	let icon_is_syncing_title = '';
	let icon_is_working_class = '';
	let icon_is_working_title = '';
	let icon_core_files_downloaded_class = '';
	let icon_core_files_downloaded_title = '';

	let is_working = false;
	// const unsub_core_file_status = coreFileStatus.subscribe((value) => {
	// 	core_file_status = value;
	// });
	// const unsub_daemon_running_status = daemonRunningStatus.subscribe((value) => {
	// 	daemon_running_status = value;
	// });

	const unsub_is_working = isWorking.subscribe((value) => {
		is_working = value;
	});

	// const unsub_wallet_connections = walletConnections.subscribe((value) => {
	// 	wallet_connections = value;
	// });

	// const unsub_wallet_verification_progress = verificationProgress.subscribe((value) => {
	// 	wallet_verification_progress = value;
	// });

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
</script>

<main>
	<div class="flex flex-wrap -mx-2 items-start">
		<!--		Working-->
		{#if daemon_running_status === DaemonRunningStatusType.drst_starting || core_files_status === CoreFileStatusType.cfst_downloading || (daemon_running_status === DaemonRunningStatusType.drst_running && wallet_connections < 1)}
			<div class="px-1 sm:px-2 py-2 sm:py-5">
				<span title="Working..."
					><i
						class="fa-solid fa-cog fa-spin animate-spin duration-300" id="icon-size"
						style={`color: ${coin_colour_primary}`}
					/></span
				>
			</div>
		{:else}
			<div class="px-1 sm:px-2 py-2 sm:py-5">
				<span title="Idle"
					><i
						class="fa-solid fa-cog fa-spin-stop" id="icon-size"
						style={`color: ${coin_colour_primary}`}
					/></span
				>
			</div>
		{/if}

		<!--		Core file status-->
		{#if core_files_status === CoreFileStatusType.cfst_installed}
			<div class="px-1 sm:px-2 py-2 sm:py-5">
				<span title="Core files have been downloaded"
					><i
						class="fa-solid fa-download" id="icon-size"
						style={`color: ${coin_colour_secondary}`}
					/></span
				>
			</div>
		{:else}
			<div class="px-1 sm:px-2 py-2 sm:py-5">
				<span title="Core files need to be downloaded"
					><i class="fa-solid fa-download disabled-icon" id="icon-size"/></span
				>
			</div>
		{/if}

		<!--		Daemon is running-->
		{#if daemon_running_status === DaemonRunningStatusType.drst_running}
			<div class="px-1 sm:px-2 py-2 sm:py-5">
				<span title="Core wallet is ready."
					><i
						class="fa-solid fa-face-smile" id="icon-size"
						style={`color: ${coin_colour_thirdly}`}
					/></span
				>
			</div>
		{:else}
			<div class="px-1 sm:px-2 py-2 sm:py-5">
				<span title="Core wallet is not ready."
					><i class="fa-solid fa-face-smile disabled-icon" id="icon-size"/></span
				>
			</div>
		{/if}

		<!--		Wallet connections-->
		{#if wallet_connections > 0}
			<div class="px-1 sm:px-2 py-2 sm:py-5">
				<span title="{wallet_connections} connections"
					><i
						class="fa-solid fa-network-wired" id="icon-size"
						style={`color: ${coin_colour_fourthly}`}
					/></span
				>
			</div>
		{:else}
			<div class="px-1 sm:px-2 py-2 sm:py-5">
				<span title="Not connected"
					><i class="fa-solid fa-network-wired disabled-icon" id="icon-size"/></span
				>
			</div>
		{/if}

		<!--		Sync Progress -->
		{#if wallet_verification_progress < 0.99999 && wallet_connections > 0}
			<div class="px-1 sm:px-2 py-2 sm:py-5">
				<span title="Blockchain is syncing... Blocks: {Math.round(block_height).toLocaleString()}"
					><i
						class="fa-solid fa-rotate fa-spin" id="icon-size"
						style={`color: ${coin_colour_primary}`}
					/></span
				>
			</div>
		{:else if wallet_connections > 0}
			<div class="px-1 sm:px-2 py-2 sm:py-5">
				<span title="Blockchain is synced. Blocks: {Math.round(block_height).toLocaleString()}"
					><i
						class="fa-solid fa-rotate fa-spin-stop" id="icon-size"
						style={`color: ${coin_colour_primary}`}
					/></span
				>
			</div>
		{:else}
			<div class="px-1 sm:px-2 py-2 sm:py-5">
				<span title="Offline"
					><i class="fa-solid fa-rotate fa-spin-stop disabled-icon" id="icon-size"/></span
				>
			</div>
		{/if}

		<!--		Wallet security status -->
		{#if wallet_unlocked_until === 0}
			<div class="px-1 sm:px-2 py-2 sm:py-5">
				<span title="Wallet locked."
					><i class="fa-solid fa-lock" id="icon-size" style={`color: ${coin_colour_secondary}`} /></span
				>
			</div>
		{:else if wallet_unlocked_until === -1}
			<div class="px-1 sm:px-2 py-2 sm:py-5">
				<span title="Wallet unlocked!"
					><i
						class="fa-solid fa-lock-open" id="icon-size"
						style={`color: ${coin_colour_secondary}`}
					/></span
				>
			</div>
		{:else if wallet_unlocked_until === -5}
			<div class="px-1 sm:px-2 py-2 sm:py-5">
				<span title="Offline"><i class="fa-solid fa-lock disabled-icon" id="icon-size"/></span>
			</div>
		{:else if wallet_unlocked_until > 0}
			<div class="px-1 sm:px-2 py-2 sm:py-5">
				<span title="Wallet unlocked for staking."
					><i class="fa-solid fa-lock" id="icon-size" style={`color: ${coin_colour_secondary}`} /></span
				>
			</div>
		{/if}

		<!--		Wallet Staking Status -->
		{#if wallet_unlocked_until === 0}
			<div class="px-1 sm:px-2 py-2 sm:py-5">
				<span title="Not staking - wallet locked"
					><i class="fa-solid fa-microchip fa-spin-stop disabled-icon" id="icon-size"/></span
				>
			</div>
		{:else if wallet_unlocked_until > 0}
			<div class="px-1 sm:px-2 py-2 sm:py-5">
				<span title="Wallet offline"
					><i
						class="fa-solid fa-microchip fa-spin-stop fa-fade"
						style={`color: ${coin_colour_secondary}; --fa-animation-duration: 5s; --fa-fade-opacity: 0.1;`}
					/></span
				>
			</div>
		{:else}
			<div class="px-1 sm:px-2 py-2 sm:py-5">
				<span title="Wallet offline"
				><i class="fa-solid fa-microchip fa-spin-stop disabled-icon" id="icon-size"/></span
				>
			</div>
		{/if}
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

  @media (min-width: 320px) { /* Tailwind's 'sm' breakpoint */
      #icon-size {
          font-size: 1em; /* Equivalent to fa-2x */
      }
  }

  @media (min-width: 480px) { /* Tailwind's 'sm' breakpoint */
      #icon-size {
          font-size: 1.5em; /* Equivalent to fa-2x */
      }
  }

  @media (min-width: 640px) { /* Tailwind's 'sm' breakpoint */
      #icon-size {
          font-size: 2em; /* Equivalent to fa-2x */
      }
  }
</style>
