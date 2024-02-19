<script lang="ts">
	import { walletVersion } from '$lib/rdd_getnetworkinfo_store';
	import { tweened } from 'svelte/motion';

	let wallet_version = tweened(0, {
		duration: 3000,
		easing: cubicOut
	});
	import { cubicOut } from 'svelte/easing';

	const unsub_walletVersion = walletVersion.subscribe((value) => {
		$wallet_version = value;
	});
</script>

<main>
	<!--	<figure class="bg-opacity-90 rounded-xl p-2 dark:bg-opacity-90">-->
	<figure class="p-2 pr-10">
		<div class="label">
			{#if $wallet_version === 0}
				v<span class="version">...</span>
			{:else}
				v<div class="version">{wallet_version}</div>
			{/if}
		</div>
	</figure>
</main>

<style>
    .version {
        font-family: 'Courier Prime', monospace;
        font-size: 1.0em;
    }
    .label {
        font-size: 0.9em;
    }

</style>