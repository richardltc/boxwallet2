<script lang="ts">
	import { headers } from '$lib/rdd/rdd_getblockchaininfo_store.js';
	import { tweened } from 'svelte/motion';

	//let header_height: number;
	let header_height = tweened(0, {
		duration: 5000,
		easing: cubicOut
	});
	import { cubicOut } from 'svelte/easing';

	const unsub_headers = headers.subscribe((value) => {
		$header_height = value;
	});
</script>

<main>
	<figure class="p-2 pr-10">
		<div class="label">
			{#if $header_height === 0}
				Headers: <div class="headers">...</div>
			{:else}
				Headers: <div class="headers">{Math.round($header_height).toLocaleString()}</div>
			{/if}
		</div>
	</figure>
</main>

<style>
	.headers {
		font-family: 'Courier Prime', monospace;
		font-size: 1.2em;
	}
	.label {
		font-size: 1.0em;
		/*color: #7ca071;*/
	}

</style>
