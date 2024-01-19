<script>
import BlockchainBlocks from '$lib/BlockchainInfoBlocks.svelte';
import BlockchainHeaders from '$lib/BlockchainInfoHeaders.svelte';
import BlockchainInfoDifficulty from '$lib/BlockchainInfoDifficulty.svelte';
</script>

<main>
<!--	Make work for mobile-->
	<div class="flex flex-wrap sm:space-x-10 items-start">
		<BlockchainHeaders/>
		<BlockchainBlocks/>
		<BlockchainInfoDifficulty/>
	</div>
</main>