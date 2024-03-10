import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

export function PopulateConfFile(
	confFile: string,
	homeDir: string,
	rpcUserCoin: string,
	rpcPortCoin: string
): { rpcUser: string; rpcPassword: string } | Error {
	try {
		console.log(`${new Date().toISOString()} Populating conf file if required...`);
		// Create home directory if it doesn't exist
		fs.mkdirSync(homeDir, { recursive: true });

		const fullConfFilePath = path.join(homeDir, confFile);

		// Read existing configuration, if any.
		const existingConfig = fs.existsSync(fullConfFilePath)
			? fs.readFileSync(fullConfFilePath, 'utf-8').trim()
			: '';

		let rpc_pw = getConfigValue(existingConfig, 'rpcpassword');
		if (rpc_pw == '' || rpc_pw === undefined) {
			console.log(`${new Date().toISOString()} Password is blank so generating...`);
			rpc_pw = generateRandomPassword();
		} else {
			console.log(`${new Date().toISOString()} Password already exists`);
		}
		// Construct updated configuration with necessary properties
		const updatedConfig = [
			`rpcuser=${rpcUserCoin || getConfigValue(existingConfig, 'rpcuser')}`,
			`rpcpassword=${rpc_pw}`,
			'daemon=1',
			'server=1',
			'rpcallowip=192.168.1.0/255.255.255.0',
			`rpcport=${rpcPortCoin || getConfigValue(existingConfig, 'rpcport')}`
		].join('\n');

		// Write updated configuration to file
		fs.writeFileSync(fullConfFilePath, updatedConfig);

		// Extract RPC user and password from the updated configuration
		const rpcUser = getConfigValue(updatedConfig, 'rpcuser') ?? '';
		const rpcPassword = getConfigValue(updatedConfig, 'rpcpassword') ?? '';

		return { rpcUser, rpcPassword };
	} catch (error: any) {
		return error;
	}
}

// Helper functions for clarity and reusability
function getConfigValue(config: string, key: string): string | undefined {
	const match = config.match(`${key}=(.*)`);
	return match ? match[1].trim() : undefined;
}

function generateRandomPassword(): string {
	const random_bytes = crypto.randomBytes(10); // Generate 10 bytes for a 20-character hex string
	const random_pw = random_bytes.toString('hex').slice(0.2); //crypto.randomBytes(20).toString('hex'); // Use crypto module for secure password generation
	console.log(`Password generated as: ${random_pw}`);
	return random_pw;
}
