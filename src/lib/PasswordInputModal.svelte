<script lang="ts">
	export let show_modal = false; // boolean

	let dialog: HTMLDialogElement // HTMLDialogElement
	let isOpen = false;
	let password = '';
	let errorMessage = '';

	function 	openModal() {
		isOpen = true;
		errorMessage = ''; // Clear previous errors
	}

	function closeModal() {
		isOpen = false;
		password = '';
	}


	$: if (dialog && show_modal) dialog.showModal();

	function submitPassword(event) {
		event.preventDefault();

		// **Replace with your actual password validation logic**
		if (password === 'safe_password') {
			// **Handle successful authentication here**
			closeModal();
			console.log('Password accepted!');
		} else {
			errorMessage = 'Incorrect password. Please try again.';
		}
	}
</script>

<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-noninteractive-element-interactions -->
<dialog
	bind:this={dialog}
	on:close={() => (show_modal = false)}
	on:click|self={() => dialog.close()}
>
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div on:click|stopPropagation>
		<slot name="header" />
		<hr />
		<slot />
		<hr />
		<form on:submit={submitPassword}>
			<div class="form-group">
				<label for="password">Password:</label>
				<input
					type="password"
					id="password"
					bind:value={password}
					required
				/>
				{#if errorMessage}
					<p class="error-message">{errorMessage}</p>
				{/if}
			</div>
			<button type="submit">Submit</button>
			<button type="button" on:click={closeModal}>Cancel</button>
		</form>

		<!-- svelte-ignore a11y-autofocus -->
		<button autofocus on:click={() => dialog.close()}>close modal</button>
	</div>
</dialog>

<style>
    dialog {
        max-width: 32em;
        border-radius: 0.2em;
        border: none;
        padding: 0;
    }
    dialog::backdrop {
        background: rgba(0, 0, 0, 0.3);
    }
    dialog > div {
        padding: 1em;
    }
    dialog[open] {
        animation: zoom 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
    }
    @keyframes zoom {
        from {
            transform: scale(0.95);
        }
        to {
            transform: scale(1);
        }
    }
    dialog[open]::backdrop {
        animation: fade 0.2s ease-out;
    }
    @keyframes fade {
        from {
            opacity: 0;
        }
        to {
            opacity: 1;
        }
    }
    button {
        display: block;
    }
</style>
