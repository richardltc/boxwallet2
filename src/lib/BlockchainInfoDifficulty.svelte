<script lang="ts">
	import { difficulty } from '$lib/rdd/rdd_getblockchaininfo_store.js';
	import { tweened } from 'svelte/motion';

	let difficulty_value = tweened(0, {
		duration: 5000,
		easing: cubicOut
	});
	import { cubicOut } from 'svelte/easing';

	const unsub_difficulty = difficulty.subscribe((value) => {
		$difficulty_value = value;
	});
</script>

<main>
	<figure class="bg-opacity-90 rounded-xl p-2 dark:bg-opacity-90">
		<div class="label">
			{#if $difficulty_value === 0}
				Difficulty: <div class="headers">...</div>
			{:else}
				Difficulty: <div class="headers">{(Math.round($difficulty_value * 100) / 100).toLocaleString()}</div>
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
    }

</style>