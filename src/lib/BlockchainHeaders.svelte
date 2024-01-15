<script lang="ts">
    import { headers } from '$lib/rdd_getblockchaininfo_store.js';
		import { CoinMethodType } from '$lib/bwtypes';
		import { tweened } from 'svelte/motion';

    //let header_height: number;
		let header_height = tweened(0, {
			duration: 3000,
			easing: cubicOut
		});
		import { cubicOut } from 'svelte/easing';

    const unsub_headers = headers.subscribe((value) => {
        $header_height = value

    })

</script>
<main>
	<div class="container mx-auto p-8 space-y-4">
		<p>
			Headers: {Math.round($header_height).toLocaleString()}
		</p>
	</div>

</main>

<style>
</style>