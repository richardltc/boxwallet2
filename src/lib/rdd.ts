import axios, { AxiosError } from 'axios';
import { getValueFromFile } from '$lib/string_utils';
import type { GetInfoResponse, GetBlockchainInfoResponse, StopResponse } from '$lib/rdd_types';
// import type { CoinAPIResponse } from '$lib/bwtypes';
import os from 'os';
import { exec } from 'child_process';
import type { ChildProcess } from 'child_process';
import * as child_process from 'child_process';
import path from 'path';
import { error } from '@sveltejs/kit';
import fs from 'fs';

const cli_file_lin = 'reddcoin-cli';
const cli_file_win = 'reddcoin-cli.exe';
const daemon_file_lin = 'reddcoind';
const daemon_file_win = 'reddcoind.exe';

const coin_name = 'ReddCoin';
const coin_name_abbrev = 'RDD';
const coin_core_version = '3.10.3';

const download_file_arm32 = 'reddcoin-' + coin_core_version + '-armhf.zip';
const download_file_lin64: string = 'reddcoin-' + coin_core_version + '-linux64.tar.gz';
const download_file_win: string = 'reddcoin-' + coin_core_version + '-win64.zip';
const download_file_bs = 'blockchain-latest.zip';

const download_url: string =
	'https://download.reddcoin.com/bin/reddcoin-core-' + coin_core_version + '/';
const download_url_arm: string =
	'https://sourceforge.net/projects/reddpi/files/update/reddcoin-' +
	coin_core_version +
	'-armhf.zip/download';
const download_url_bs = 'https://download.reddcoin.com/bin/bootstrap/';

const extracted_dir_lin: string = 'reddcoin-' + coin_core_version + '/';
const extracted_dir_win: string = 'reddcoin-' + coin_core_version + '\\';

const home_dir = os.homedir();
const home_dir_boxwallet = '.boxwallet';
const home_dir_lin = '.reddcoin';
const home_dir_win = 'REDDCOIN';

const min_tx_fee = 0.004;

const rpc_user = 'reddcoinrpc';
const rpc_port = '45443';

const tip_address = 'RtH6nZvmnstUsy5w5cmdwTrarbTPm6zyrC';

class ReddCoin {
	private conf_file: string;

	public download_file_lin64: string = 'reddcoin-' + coin_core_version + '-linux64.tar.gz';
	public download_link = download_url + download_file_lin64;

	public ip_address = '127.0.0.1';
	private rpc_password: string;
	public rpc_port: string = rpc_port;

	constructor(confFile: string) {
		this.conf_file = confFile;
		// this.rpc_user = '';
		this.rpc_password = '';
	}

	private async initialize(): Promise<void> {
		try {
			this.rpc_password = await getValueFromFile(this.conf_file, 'rpcpassword=');
		} catch (error) {
			console.error('Error processing file:', error);
		}
	}

	public static async getInstance(confFile: string) {
		const instance = new ReddCoin(confFile);
		await instance.initialize();
		return instance;
	}

	public async CoinDaemonIsReady(): Promise<boolean> {
		const body = '{"jsonrpc":"1.0","id":"curltext","method":"getinfo","params":[]}';
		const url = `http://${this.ip_address}:${this.rpc_port}`;
		const config = {
			auth: {
				username: rpc_user,
				password: this.rpc_password
			},
			headers: {
				'Content-Type': 'text/plain'
			}
		};

		let response_data: GetInfoResponse;
		try {
			const response = await axios.post(url, body, config);
			response_data = response.data as GetInfoResponse;

			// If we get here, it's because we didn't get any kind of error...
			return true;
		} catch (error: any | AxiosError) {
			if (axios.isAxiosError(error) && error.response) {
				const json = JSON.stringify(error.response.data);
				if (json.includes('Loading')) {
					return false;
				} else {
					console.log(`Loading not found, instead error: ${error.response.data}`);
					console.error('Error data:', error.response.data);
				}
			}
		}
		return false;
	}

	public async CoinDaemonIsRunning(): Promise<boolean> {
		return new Promise((resolve, reject) => {
			if (process.platform === 'win32') {
				// For Windows
				const command = `tasklist /FI "IMAGENAME eq ${daemon_file_win}.exe" /NH`;

				exec(command, (error, stdout) => {
					if (error) {
						reject(error);
						return;
					}

					resolve(stdout.toLowerCase().includes(daemon_file_win.toLowerCase()));
				});
			} else if (process.platform === 'darwin' || process.platform === 'linux') {
				// For macOS and Linux
				const command = `ps aux | grep ${daemon_file_lin} | grep -v grep`;

				exec(command, (error, stdout, stderr) => {
					if (error && stderr && !stderr.includes('grep:')) {
						// Ignore the error if the command did not find any matching processes
						resolve(false);
					} else {
						resolve(stdout.toLowerCase().includes(daemon_file_lin.toLowerCase()));
					}
				});
			} else {
				// Unsupported platform
				reject(new Error('Unsupported platform'));
			}
		});
	}

	public async CoreFilesExist(): Promise<boolean> {
		if (process.platform === 'win32') {
			throw new Error('Not currently implemented for Windows');
			// For Windows
		} else if (process.platform === 'darwin' || process.platform === 'linux') {
			// For macOS and Linux
			if (fs.existsSync(path.join(home_dir, home_dir_boxwallet, daemon_file_lin))) {
				// File exists in path
				console.log('file exists ' + home_dir + '/.boxwallet/' + cli_file_lin);
				return true;
			} else {
				console.log('file does not exist ' + home_dir + '/.boxwallet/' + cli_file_lin);
				return false;
			}
		}
		{
			// Unsupported platform
			throw new Error('Unsupported platform');
		}
	}

	public async GetBlockchainInfo(): Promise<GetBlockchainInfoResponse> {
		const body = '{"jsonrpc":"1.0","id":"curltext","method":"getblockchaininfo","params":[]}';
		const url = `http://${this.ip_address}:${this.rpc_port}`;
		const config = {
			auth: {
				username: rpc_user,
				password: this.rpc_password
			},
			headers: {
				'Content-Type': 'text/plain'
			}
		};

		let response_data: GetBlockchainInfoResponse;
		try {
			const response = await axios.post(url, body, config);
			response_data = response.data as GetBlockchainInfoResponse;

			// If we get here, it's because we didn't get any kind of error...
			console.log('response', JSON.stringify(response_data)); //log(`response: ${response_data}`);
			return response_data;
		} catch (error: any | AxiosError) {
			// console.error('Error:', error);
			console.log('In catch...');
			if (axios.isAxiosError(error) && error.response) {
				console.log('Error detected...');
				const json = JSON.stringify(error.response.data);
				console.log(`json = ${json}`);
				if (json.includes('Loading')) {
					console.log('Loading...');
					response_data = error.response.data;
					return response_data;
				} else {
					console.log(`Loading not found, instead error: ${error.response.data}`);
					console.error('Error data:', error.response.data);
				}
			}
			return response_data;
		}
	}

	public async GetInfo(): Promise<GetInfoResponse> {
		const body = '{"jsonrpc":"1.0","id":"curltext","method":"getinfo","params":[]}';
		const url = `http://${this.ip_address}:${this.rpc_port}`;
		const config = {
			auth: {
				username: rpc_user,
				password: this.rpc_password
			},
			headers: {
				'Content-Type': 'text/plain'
			}
		};

		let response_data: GetInfoResponse;
		try {
			const response = await axios.post(url, body, config);
			response_data = response.data as GetInfoResponse;

			// If we get here, it's because we didn't get any kind of error...
			// console.log(`response: ${JSON.stringify(response_data)}`);
			console.log('response', JSON.stringify(response_data)); //log(`response: ${response_data}`);
			return response_data;
		} catch (error: any | AxiosError) {
			// console.error('Error:', error);
			console.log('In catch...');
			// Check if the error contains Loading, and if so return a good response
			if (axios.isAxiosError(error) && error.response) {
				console.log('Error detected...');
				const json = JSON.stringify(error.response.data);
				console.log(`json = ${json}`);
				if (json.includes('Loading')) {
					console.log('Loading...');
					response_data = error.response.data;
					return response_data;
				} else {
					console.log(`Loading not found, instead error: ${error.response.data}`);
					console.error('Error data:', error.response.data);
				}
				// Axios error with a response from the server

				// You can handle the error data here or return it as needed
				// return { error: 'An error occurred', status: error.response.status, data: error.response.data };

				// You can return an error object or throw the error for further handling
				// return { error: 'An error occurred' };		}
			}
			return response_data;
		}
	}
	public async StartDaemon(): Promise<boolean> {
		let is_running = await this.CoinDaemonIsRunning();

		if (!is_running) {
			const command = path.join(home_dir, home_dir_boxwallet, daemon_file_lin);

			if (process.platform === 'win32') {
				// const command = `${home_dir}${daemon_file_win}`;

				const process: ChildProcess = child_process.spawn(command);

				await new Promise((resolve, reject) => {
					process.on('exit', (code) => {
						if (code === 0) {
							is_running = true;
							resolve(true);
						} else {
							reject(new Error(`Failed to start daemon: ${code}`));
						}
					});
				});
				is_running = true;
			} else if (process.platform === 'darwin' || process.platform === 'linux') {
				// For macOS and Linux
				// const command = path.join(home_dir, home_dir_boxwallet, daemon_file_lin);

				const process: ChildProcess = child_process.spawn(command);

				await new Promise((resolve, reject) => {
					process.on('error', (err) => {
						// Handle the spawn error
						console.error(`Failed to spawn daemon: ${err.message}`);
						// Reject the promise with the error
						reject(new Error(`Failed to spawn daemon: ${err.message}`));
					});
					process.on('exit', (code) => {
						if (code === 0) {
							is_running = true;
							resolve(true);
						} else {
							reject(new Error(`Failed to start daemon: ${code}`));
						}
					});
				});
			} else {
				// Unsupported platform
				reject(new Error('Unsupported platform'));
			}
		}
		return is_running;
	}

	public async StopDaemon(): Promise<StopResponse> {
		const is_running = await this.CoinDaemonIsRunning();
		let response_data: StopResponse = {
			result: '',
			error: null,
			id: ''
		};

		if (!is_running) {
			return response_data;
		}

		const body = '{"jsonrpc":"1.0","id":"curltext","method":"stop","params":[]}';
		const url = `http://${this.ip_address}:${this.rpc_port}`;
		const config = {
			auth: {
				username: rpc_user,
				password: this.rpc_password
			},
			headers: {
				'Content-Type': 'text/plain'
			}
		};

		try {
			const response = await axios.post(url, body, config);
			response_data = response.data as StopResponse;

			console.log(`response: ${response_data}`);
			return response_data;
		} catch (error: any | AxiosError) {
			console.error('Error data:', error.response.data);
		}
		return response_data;
	}
}

export default ReddCoin;
