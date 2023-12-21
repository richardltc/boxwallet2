import { writable } from 'svelte/store';

// From GetInfo
export const walletConnections = writable(0);
export const walletUnlockedUntil = writable(-5);
