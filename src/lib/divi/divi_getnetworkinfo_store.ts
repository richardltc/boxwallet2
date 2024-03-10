import { writable } from 'svelte/store';

// From GetNetworkInfo API for Divi
export const walletConnections = writable(0);
export const walletUnlockedUntil = writable(-5);
export const walletVersion = writable(0);
