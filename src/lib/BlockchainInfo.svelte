<script>
import BlockchainBlocks from '$lib/BlockchainInfoBlocks.svelte';
import BlockchainHeaders from '$lib/BlockchainInfoHeaders.svelte';
import BlockchainInfoDifficulty from '$lib/BlockchainInfoDifficulty.svelte';

export let headers = 0;
export let blocks = 0;
export let difficulty = 0;
</script>

<main>
<!--	Make work for mobile-->
	<div class="flex flex-wrap sm:space-x-10 items-start">
		<BlockchainHeaders
			header_height={headers}
		/>
		<BlockchainBlocks
			blocks_height={blocks}
		/>
		<BlockchainInfoDifficulty
		  difficulty_value={difficulty}
		/>
	</div>
</main>