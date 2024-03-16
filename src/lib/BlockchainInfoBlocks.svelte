<script lang="ts">
	import { cubicInOut, cubicOut } from 'svelte/easing';
	import { tweened } from 'svelte/motion';

	export let blocks_height = 0;

	let tweened_blocks_height = tweened(blocks_height, {
		duration: 7500,
		easing: cubicInOut
	});

	$: {
		tweened_blocks_height.set(blocks_height);
	}

</script>

<main>
<!--	<figure class="bg-opacity-90 rounded-xl p-2 dark:bg-opacity-90">-->
	<figure class="p-2 pr-10">
		<div class="label">
			{#if blocks_height === 0}
				Blocks: <div class="blocks">...</div>
			{:else}
				Blocks: <div class="blocks">{Math.round($tweened_blocks_height).toLocaleString()}</div>
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
