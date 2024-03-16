<script lang="ts">
	import { tweened } from 'svelte/motion';

	export let difficulty_value = 0;

	import { cubicInOut, cubicOut } from 'svelte/easing';

	let tweened_difficulty_value = tweened(difficulty_value, {
		duration: 3000,
		easing: cubicInOut
	});

	$: {
		tweened_difficulty_value.set(difficulty_value);
	}

	//const unsub_difficulty = difficulty.subscribe((value) => {
	//	$difficulty_value = value;
	//});
</script>

<main>
	<figure class="bg-opacity-90 rounded-xl p-2 dark:bg-opacity-90">
		<div class="label">
			{#if $tweened_difficulty_value === 0}
				Difficulty: <div class="headers">...</div>
			{:else}
				Difficulty: <div class="headers">{(Math.round($tweened_difficulty_value * 100) / 100).toLocaleString()}</div>
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