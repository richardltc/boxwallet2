import { writable } from 'svelte/store';

// From GetNetworkInfo API.
export const walletConnections = writable(0);
export const walletUnlockedUntil = writable(-5);
export const coinWalletVersion = writable(0);
