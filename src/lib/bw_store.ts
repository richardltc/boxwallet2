import { writable } from 'svelte/store';
import { CoreFileStatusType, DaemonRunningStatusType } from '$lib/bwtypes';

// Various BoxWallet states.
export const coreFileStatus = writable(CoreFileStatusType.cfst_not_installed);
export const daemonRunningStatus = writable(DaemonRunningStatusType.drst_stopped);
export const isWorking = writable(false);
