<script lang="ts">
	import { onMount } from 'svelte';
	import { getModalStore, type ModalSettings } from '@skeletonlabs/skeleton';

	export let resolveFunction: (value: string) => void;
	const modalStore = getModalStore();


	const modal: ModalSettings = {
		type: 'confirm',
		title: 'Enter password to unlock wallet',
		body: 'Enter password?',
		response: (r: string) => {
			resolveFunction(r);
		},
	};

	onMount(() => {
		// Assuming modalStore is your store for managing modals
		modalStore.trigger(modal);
	});
</script>
