<script lang="ts">
	import { blocks } from '$lib/rdd_getblockchaininfo_store.js';
	import { tweened } from 'svelte/motion';

	let blocks_height = tweened(0, {
		duration: 5000,
		easing: cubicOut
	});
	import { cubicOut } from 'svelte/easing';

	const unsub_blocks = blocks.subscribe((value) => {
		$blocks_height = value;
	});
</script>

<main>
	<figure class="bg-opacity-90 rounded-xl p-2 dark:bg-opacity-90">
		<div class="label">
			{#if $blocks_height === 0}
				Blocks: <div class="blocks">...</div>
			{:else}
				Blocks: <div class="blocks">{Math.round($blocks_height).toLocaleString()}</div>
			{/if}
		</div>
	</figure>
</main>

<style>
    .blocks {
        font-family: 'Courier Prime', monospace;
        font-size: 1.2em;
    }
    .label {
        font-size: 1.0em;
    }

</style>
