import { writable } from 'svelte/store';

// Various BoxWallet states.
// export const diviCoreFileStatus = writable(CoreFileStatusType.cfst_not_installed);
// export const rddCoreFileStatus = writable(CoreFileStatusType.cfst_not_installed);
// export const diviDaemonRunningStatus = writable(DaemonRunningStatusType.drst_stopped);
// export const rddDaemonRunningStatus = writable(DaemonRunningStatusType.drst_stopped);
export const isWorking = writable(false);
