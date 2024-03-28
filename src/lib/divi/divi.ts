import axios, { AxiosError } from 'axios';
import compressing from 'compressing';
import { getValueFromFile } from '$lib/string_utils';
import type {
	GetNetworkInfoResponse,
	GetBlockchainInfoResponse,
	GenericResponse,
	GetWalletInfoResponse,
	GetStakingStatusResponse
} from '$lib/divi/divi_types';
import os from 'os';
import { exec } from 'child_process';
import type { ChildProcess } from 'child_process';
import * as child_process from 'child_process';
import path from 'path';
import { error } from '@sveltejs/kit';
import fs from 'fs';
import { download_file } from '$lib/web_utils';
import { copyFileSync, rmdirSync } from 'node:fs';
import * as coin_utils from '$lib/coin_utils';

const cli_file_lin = 'divi-cli';
const cli_file_win = 'divi-cli.exe';
const daemon_file_lin = 'divid';
const daemon_file_win = 'divid.exe';

const coin_name = 'Divi';
// const coin_name_abbrev = 'DIVI';
const coin_core_version = '3.0.0';

const download_file_arm32 = 'divi-3.0.0-RPi2-9e2f76c.tar.gz';
// const download_file_arm64 = 'reddcoin-1d0e612e3f0c-aarch64-linux-gnu.tar.gz';
const download_file_lin64 = 'divi-3.0.0-x86_64-linux-gnu-9e2f76c.tar.gz';
// const download_file_win: string = 'reddcoin-' + coin_core_version + '-win64.zip';
// const download_file_bs = 'blockchain-latest.zip';

const download_url_lin64: string =
	// https://github.com/DiviProject/Divi/releases/download/v3.0.0/divi-3.0.0-x86_64-linux-gnu-9e2f76c.tar.gz
	'https://github.com/DiviProject/Divi/releases/download/v' + coin_core_version + '/';
const download_url_arm32: string =
	'https://github.com/DiviProject/Divi/releases/download/v' + coin_core_version + '/';
// const download_url_arm64: string =
// 	'https://github.com/DiviProject/Divi/releases/download/v';

// const download_url_bs = 'https://download.reddcoin.com/bin/bootstrap/';

const extracted_dir_lin = 'divi-3.0.0';
const extracted_dir_win = 'divi-3.0.0';

const home_dir = os.homedir();
const home_dir_boxwallet = '.boxwallet';
const home_dir_lin = '.divi';
const home_dir_win = 'DIVI';

// const min_tx_fee = 0.004;

const conf_file = 'divi.conf';
const rpc_user = 'divirpc';
const rpc_port = '45443';

const tip_address = 'DM5XJbB6kpyDXpbnYcb1ZidrNpubf2gmSN';

class Divi {
	private conf_file: string;

	public coin_name = coin_name;
	public download_link = download_url_lin64 + download_file_lin64;

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
			// Populate reddcoin.conf file, if required...
			try {
				coin_utils.PopulateConfFile(
					conf_file,
					path.join(os.homedir(), home_dir_lin),
					rpc_user,
					rpc_port
				);
			} catch (error) {
				console.error('Error populating conf file:', error);
			}

			this.rpc_password = await getValueFromFile(this.conf_file, 'rpcpassword=');
		} catch (error) {
			console.error('Error processing file:', error);
		}
	}

	public static async getInstance(confFile: string) {
		const instance = new Divi(confFile);
		await instance.initialize();
		return instance;
	}

	public async CoinDaemonIsReady(): Promise<boolean> {
		const body = '{"jsonrpc":"1.0","id":"curltext","method":"getnetworkinfo","params":[]}';
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

		let response_data: GetNetworkInfoResponse;
		try {
			const response = await axios.post(url, body, config);
			response_data = response.data as GetNetworkInfoResponse;

			// If we get here, it's because we didn't get any kind of error.
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
						// Ignore the error if the command did not find any matching processes.
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
		console.log('Hitting CoreFilesExist in server.ts ');
		if (process.platform === 'win32') {
			throw new Error('Not currently implemented for Windows');
			// For Windows
		} else if (process.platform === 'darwin' || process.platform === 'linux') {
			// For macOS and Linux
			if (fs.existsSync(path.join(home_dir, home_dir_boxwallet, daemon_file_lin))) {
				return true;
			} else {
				console.log('file does not exist ' + home_dir + '/.boxwallet/' + cli_file_lin);
				return false;
			}
		}
		{
			// Unsupported platform.
			throw new Error('Unsupported platform');
		}
	}

	public async CreateWalletIfRequired(name: string): Promise<GenericResponse> {
		const body = `{"jsonrpc":"1.0","id":"curltext","method":"createwallet","params":["${name}"]}`;
		console.log(`body: ${body}`);
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
		let response_data: GenericResponse = {
			result: '',
			error: null,
			id: ''
		};

		try {
			const response = await axios.post(url, body, config);
			response_data = response.data as GenericResponse;

			console.log(`response: ${response_data}`);
			return response_data;
		} catch (error: any | AxiosError) {
			console.error('Error data:', error.response.data);
		}
		return response_data;
	}

	public async DownloadCoreFiles(): Promise<void> {
		let dl_url = '';
		let dl_file = '';
		switch (process.arch) {
			case 'arm':
				dl_url = download_url_arm32 + download_file_arm32;
				dl_file = download_file_arm32;
				break;
			case 'arm64':
				dl_url = download_url_arm64 + download_file_arm64;
				dl_file = download_file_arm64;
				break;
			case 'x64':
				dl_url = download_url_lin64 + download_file_lin64;
				dl_file = download_file_lin64;
				break;
		}
		await download_file(dl_url, path.join(home_dir, home_dir_boxwallet, dl_file))
			.then(() => {
				console.log(
					'File downloaded successfully to:',
					path.join(home_dir, home_dir_boxwallet, dl_file)
				);
			})
			.catch((error) => {
				console.error('Error downloading file:', error);
			});
		// un-compress the file
		await compressing.tgz
			.uncompress(
				path.join(home_dir, home_dir_boxwallet, dl_file),
				path.join(home_dir, home_dir_boxwallet)
			)
			.then(() => {
				console.log('File uncompressed.');
				try {
					// Copy files to correct location...
					const src_cli_file = path.join(
						home_dir,
						home_dir_boxwallet,
						extracted_dir_lin,
						'bin',
						cli_file_lin
					);
					const dest_cli_file = path.join(home_dir, home_dir_boxwallet, cli_file_lin);
					const src_daemon_file = path.join(
						home_dir,
						home_dir_boxwallet,
						extracted_dir_lin,
						'bin',
						daemon_file_lin
					);
					const dest_daemon_file = path.join(home_dir, home_dir_boxwallet, daemon_file_lin);
					console.log(`Attempting to copy: ${src_cli_file} to ${dest_cli_file}`);
					copyFileSync(src_cli_file, dest_cli_file);
					console.log(`Attempting to copy: ${src_daemon_file} to ${dest_daemon_file}`);
					copyFileSync(src_daemon_file, dest_daemon_file);

					// Tidy un-needed files
					fs.rmSync(path.join(home_dir, home_dir_boxwallet, extracted_dir_lin), {
						recursive: true,
						force: true
					});
				} catch (error) {
					console.error('Error tidying files:', error);
				}
			})
			.catch((error: any) => {
				console.error('Error while un-compressing file:', error);
			});
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

	//************************************************
	// GetNetworkInfo
	public async GetNetworkInfo(): Promise<GetNetworkInfoResponse> {
		const body = '{"jsonrpc":"1.0","id":"curltext","method":"getnetworkinfo","params":[]}';
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

		let response_data: GetNetworkInfoResponse;
		try {
			const response = await axios.post(url, body, config);
			response_data = response.data as GetNetworkInfoResponse;

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

	//************************************************
	// GetStakingStatus
	public async GetStakingStatus(): Promise<GetStakingStatusResponse> {
		const body = '{"jsonrpc":"1.0","id":"curltext","method":"getstakingstatus","params":[]}';
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

		let response_data: GetStakingStatusResponse;
		try {
			const response = await axios.post(url, body, config);
			response_data = response.data as GetStakingStatusResponse;

			// If we get here, it's because we didn't get any kind of error...
			console.log('response', JSON.stringify(response_data)); //log(`response: ${response_data}`);
			return response_data;
		} catch (error: any | AxiosError) {
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

	//************************************************
	// GetWalletInfo
	public async GetWalletInfo(): Promise<GetWalletInfoResponse> {
		const body = '{"jsonrpc":"1.0","id":"curltext","method":"getwalletinfo","params":[]}';
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

		let response_data: GetWalletInfoResponse;
		try {
			const response = await axios.post(url, body, config);
			response_data = response.data as GetWalletInfoResponse;

			// If we get here, it's because we didn't get any kind of error...
			console.log('response', JSON.stringify(response_data)); //log(`response: ${response_data}`);
			return response_data;
		} catch (error: any | AxiosError) {
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
				new Error('Unsupported platform');
			}
		}
		return is_running;
	}

	public async StopDaemon(): Promise<GenericResponse> {
		const is_running = await this.CoinDaemonIsRunning();
		let response_data: GenericResponse = {
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
			response_data = response.data as GenericResponse;

			console.log(`response: ${response_data}`);
			return response_data;
		} catch (error: any | AxiosError) {
			console.error('Error data:', error.response.data);
		}
		return response_data;
	}

	public async WalletUnlockFS(pw: string): Promise<GenericResponse> {
		const body = `{"jsonrpc":"1.0","id":"curltext","method":"walletpassphrase","params":["${pw}",999999,true]}`;
		console.log(`body: ${body}`);
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
		let response_data: GenericResponse = {
			result: '',
			error: null,
			id: ''
		};

		try {
			const response = await axios.post(url, body, config);
			response_data = response.data as GenericResponse;

			console.log(`response: ${response_data}`);
			return response_data;
		} catch (error: any | AxiosError) {
			console.log('Error detected...');
			const json = JSON.stringify(error.response.data);
			console.log(`json = ${json}`);
			if (json.includes('The wallet passphrase entered was incorrect')) {
				console.log('Incorrect passphrase detected...');
				response_data = error.response.data;
				console.log('returning:', response_data);
				return response_data;
			} else {
				console.log(`Incorrect passphrase detected, instead error: ${error.response.data}`);
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

	async WalletExists(name: string): Promise<boolean> {
		let wallet_exists = false;

		const body = `{"jsonrpc":"1.0","id":"curltext","method":"listwallets","params":[]}`;
		console.log(`body: ${body}`);
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
		let response_data: GenericResponse = {
			result: '',
			error: null,
			id: ''
		};

		try {
			const response = await axios.post(url, body, config);
			response_data = response.data as GenericResponse;

			console.log(`response: ${response_data}`);
			if (response_data.result.includes('main', 0)) {
				console.log('Wallet main exists');
				return true;
			}
		} catch (error: any | AxiosError) {
			console.error('Error data:', error.response.data);
		}
		return false;
	}
}

export default Divi;
