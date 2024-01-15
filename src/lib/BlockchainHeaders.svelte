<script lang="ts">
    import { headers } from '$lib/rdd_getblockchaininfo_store.js';
		import { CoinMethodType } from '$lib/bwtypes';

    let header_height: number;

    const unsub_headers = headers.subscribe((value) => {
        header_height = value

    })

</script>

<main>
	<div class="container mx-auto p-8 space-y-4">
		<p>
			Headers: {header_height.toLocaleString()}
		</p>
	</div>

</main>

<style>
</style>