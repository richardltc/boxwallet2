<script lang="ts">
	import { tweened } from 'svelte/motion';
	import { cubicInOut } from 'svelte/easing';

	export let coin_name_abbr = '';
	export let hidden = false;
	export let wallet_balance = 0;

	let tweened_wallet_balance = tweened(wallet_balance, {
		duration: 1000,
		easing: cubicInOut
	});

	$: {
		tweened_wallet_balance.set(wallet_balance);
	}
</script>

<main>
	<figure class="p-2 pr-10">
		<div class="label">
			{#if hidden}
				{coin_name_abbr}: <span class="balance">***</span>
			{:else}
				{coin_name_abbr}: <span class="balance">{Math.round($tweened_wallet_balance).toLocaleString()}</span>
			{/if}
		</div>
	</figure>
</main>

<style>
	.balance {
		font-family: 'Courier Prime', monospace;
		font-size: 1em;
	}
	.label {
		font-size: 0.9em;
	}
</style>
