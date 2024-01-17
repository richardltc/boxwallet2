<script>
import BlockchainBlocks from '$lib/BlockchainInfoBlocks.svelte';
import BlockchainHeaders from '$lib/BlockchainInfoHeaders.svelte';
import BlockchainInfoDifficulty from '$lib/BlockchainInfoDifficulty.svelte';
</script>

// main
<main>
	<div class="flex items-center space-x-10">
		<BlockchainHeaders/>
		<BlockchainBlocks/>
		<BlockchainInfoDifficulty/>
	</div>
</main>