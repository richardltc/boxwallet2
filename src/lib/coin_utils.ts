import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

function populateConfFile(
	confFile: string,
	homeDir: string,
	rpcUserCoin: string,
	rpcPortCoin: string
): { rpcUser: string; rpcPassword: string } | Error {
	try {
		// Create home directory if it doesn't exist
		fs.mkdirSync(homeDir, { recursive: true });

		// Ensure consistent path handling
		const fullConfFilePath = path.join(homeDir, confFile);

		// Read existing configuration, if any
		const existingConfig = fs.existsSync(fullConfFilePath)
			? fs.readFileSync(fullConfFilePath, 'utf-8').trim()
			: '';

		// Construct updated configuration with necessary properties
		const updatedConfig = [
			`rpcuser=${rpcUserCoin || getConfigValue(existingConfig, 'rpcuser')}`,
			`rpcpassword=${generateRandomPassword()}`,
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
	return crypto.randomBytes(20).toString('hex'); // Use crypto module for secure password generation
}
