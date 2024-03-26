import { writable } from 'svelte/store';
import { CoreFileStatusType, DaemonRunningStatusType } from '$lib/bw_types';
// Divi store

export const coreFileStatus = writable(CoreFileStatusType.cfst_not_installed);
export const daemonRunningStatus = writable(DaemonRunningStatusType.drst_stopped);
