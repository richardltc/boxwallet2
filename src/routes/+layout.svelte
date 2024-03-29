<script lang="ts">
	// The ordering of these imports is critical to your app working properly
	// import '@skeletonlabs/skeleton/themes/theme-skeleton.css';
	// If you have source.organizeImports set to true in VSCode, then it will auto change this ordering
	// import '@skeletonlabs/skeleton/styles/skeleton.css';
	// Most of your app wide CSS should be put in this file
	import '../app.postcss';
	import { AppShell, AppBar, Modal, Toast } from '@skeletonlabs/skeleton';
	import '@fortawesome/fontawesome-free/css/all.min.css'
	import '$lib/styles/app.scss'
	import { initializeStores } from '@skeletonlabs/skeleton';

	initializeStores();

</script>

<Toast />
<Modal position="items-center" />

<!-- <AppShell>...</AppShell> -->

<!-- App Shell -->
<AppShell slotSidebarLeft="bg-surface-500/5 p-4 w-64 sm:w-48">
	<svelte:fragment slot="sidebarLeft">
		<!-- Insert the list: -->
		<nav class="list-nav">
			<ul>
				<li><a href="/">Home</a></li>
				<li class="flex items-center">
					<img src="../divi_logo.png" alt="logo" class="h-6 mr-0">
					<a href="/coins/divi">DIVI</a>
				</li>
				<li class="flex items-center">
					<img src="../rdd_logo.png" alt="logo" class="h-6 mr-0">
					<a href="/coins/reddcoin">ReddCoin</a>
				</li>
<!--				<li><a href="/about">About</a></li>-->
			</ul>
		</nav>
		<!-- --- -->
	</svelte:fragment>

	<svelte:fragment slot="header">
		<!-- App Bar -->
		<AppBar>
			<svelte:fragment slot="lead">
				<div class ="flex items-center">
					<img src="../BoxWallet.png" alt="logo" class="mr-3 h-20">
					<div class="flex flex-col">
						<strong class="text-2xl mr-3 sm:text-4xl">BoxWallet</strong>
						<div class="text-xs">v0.06 BETA</div>
					</div>
				</div>
			</svelte:fragment>
			<svelte:fragment slot="trail">
				<a
					class="btn btn-sm variant-ghost-surface"
					href="https://t.me/boxwallet"
					target="_blank"
					rel="noreferrer"
				>
					Telegram
				</a>
				<a
					class="btn btn-sm variant-ghost-surface"
					href="https://twitter.com/box_wallet"
					target="_blank"
					rel="noreferrer"
				>
					X
				</a>
				<a
					class="btn btn-sm variant-ghost-surface"
					href="https://github.com/richardltc/boxwallet2"
					target="_blank"
					rel="noreferrer"
				>
					GitHub
				</a>
			</svelte:fragment>
		</AppBar>
	</svelte:fragment>
	<!-- Page Route Content -->
	<slot />
</AppShell>

