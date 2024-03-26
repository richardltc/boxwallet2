<!-- PasswordPromptModal.svelte -->
<script lang="ts">
	import { onMount } from 'svelte';
	import { getModalStore, type ModalSettings } from '@skeletonlabs/skeleton';
	const modalStore = getModalStore();

	export let response: (value: string) => void;

	const modal: ModalSettings = {
		type: 'prompt',
		title: 'Enter Password',
		body: 'Provide your password in the field below.',
		value: 'Skeleton',
		valueAttr: { type: 'text', minlength: 3, maxlength: 10, required: true },
		response: (r: string) => {
			response(r);
		},
	};

	onMount(() => {
		// Assuming modalStore is your store for managing modals.
		modalStore.trigger(modal);
	});
</script>

