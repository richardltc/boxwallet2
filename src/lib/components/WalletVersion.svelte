<script lang="ts">
	// import { walletVersion } from '$lib/rdd/rdd_getnetworkinfo_store';

	export let wallet_version = 0;

	//const unsub_walletVersion = walletVersion.subscribe((value) => {
	//	wallet_version = value;
	//});
</script>

<main>
	<!--	<figure class="bg-opacity-90 rounded-xl p-2 dark:bg-opacity-90">-->
	<figure class="p-2 pr-10">
		<div class="label">
			{#if wallet_version === 0}
				v<span class="version">...</span>
			{:else}
				v: <span class="version">{wallet_version}</span>
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