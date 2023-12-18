import { HttpClient } from 'typed-rest-client/HttpClient';
import fs from 'fs';

export async function download_file(url: string, file_path: string) {
	const client = new HttpClient('clientBW');
	const response = await client.get(url);
	const filePath = file_path;
	const file: NodeJS.WritableStream = fs.createWriteStream(filePath);

	if (response.message.statusCode !== 200) {
		const err: Error = new Error(`Unexpected HTTP response: ${response.message.statusCode}`);
		// err["httpStatusCode"] = response.message.statusCode;
		throw err;
	}
	return new Promise((resolve, reject) => {
		file.on('error', (err) => reject(err));
		const stream = response.message.pipe(file);
		stream.on('close', () => {
			try {
				resolve(filePath);
			} catch (err) {
				reject(err);
			}
		});
	});
}
