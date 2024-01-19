<script>
import BlockchainBlocks from '$lib/BlockchainInfoBlocks.svelte';
import BlockchainHeaders from '$lib/BlockchainInfoHeaders.svelte';
import BlockchainInfoDifficulty from '$lib/BlockchainInfoDifficulty.svelte';
</script>

<main>
<!--	Make work for mobile-->
	<div class="flex flex-wrap space-x-10 items-center">
		<BlockchainHeaders/>
		<BlockchainBlocks/>
		<BlockchainInfoDifficulty/>
	</div>
</main>