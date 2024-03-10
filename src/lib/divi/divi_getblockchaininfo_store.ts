import { writable } from 'svelte/store';

// From GetBlockchainInfo API for Divi
export const blocks = writable(0);
export const difficulty = writable(0);
export const headers = writable(0);
export const verificationProgress = writable(0);
