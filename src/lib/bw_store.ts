import { writable } from 'svelte/store';
import { CoreFileStatusType, WalletRunningStatusType } from '$lib/bwtypes';

// Various BoxWallet states.
export const coreFileStatus = writable(CoreFileStatusType.not_installed);
export const walletRunningStatus = writable(WalletRunningStatusType.wrst_stopped);
