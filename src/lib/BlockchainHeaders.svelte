<script lang="ts">
    import { headers } from '$lib/rdd_getblockchaininfo_store.js';

    let header_height: number;

    const unsub_headers = headers.subscribe((value) => {
        header_height = value

    })

</script>

<main>
</main>

<style>
</style>