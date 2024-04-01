<script lang="ts">
	import { bounceInOut, cubicIn, cubicInOut, elasticIn } from 'svelte/easing';
	import { tweened } from 'svelte/motion';

	export let header_height = 0;

	let tweened_header_height = tweened(header_height, {
		duration: 5000,
		easing: cubicInOut
	});

	$: {
		tweened_header_height.set(header_height);
	}

	//const unsub_headers = headers.subscribe((value) => {
	//	$header_height = value;
	//});
</script>

<main>
	<figure class="p-2 pr-10">
		<div class="label">
			{#if header_height !== 0}
				Headers: <div class="headers">{Math.round($tweened_header_height).toLocaleString()}</div>
			{:else}
				Headers: <div class="headers">...</div>
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
		font-size: 1em;
		/*color: #7ca071;*/
	}
</style>
