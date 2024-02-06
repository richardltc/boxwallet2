import { writable } from 'svelte/store';
import { CoreFileStatusType, DaemonRunningStatusType, WalletRunningStatusType } from '$lib/bwtypes';

// Various BoxWallet states.
export const coreFileStatus = writable(CoreFileStatusType.cfst_not_installed);
export const daemonRunningStatus = writable(DaemonRunningStatusType.drstStopped);
export const isWorking = writable(false);
export const walletRunningStatus = writable(WalletRunningStatusType.wrst_stopped);
