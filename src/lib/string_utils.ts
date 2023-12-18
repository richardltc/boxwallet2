import * as fs from 'fs';

// export async function extractValueFromFile(
// 	filePath: string,
// 	pattern: string
// ): Promise<string | null> {
// 	return new Promise((resolve, reject) => {
// 		const readStream = fs.createReadStream(filePath, 'utf8');
// 		const rl = readline.createInterface({
// 			input: readStream,
// 			crlfDelay: Infinity
// 		});
//
// 		rl.on('line', (line: string) => {
// 			// console.log('Line:', line); // Log the current line for debugging
//
// 			const patternIndex = line.indexOf(pattern);
// 			if (patternIndex !== -1) {
// 				// Extract the value after the pattern
// 				const valueStartIndex = patternIndex + pattern.length;
// 				const extractedValue = line.substring(valueStartIndex).trim();
//
// 				console.log('Extracted Value:', extractedValue); // Log the extracted value
//
// 				rl.close(); // Close the readline interface to stop reading the file
// 				resolve(extractedValue);
// 			}
// 		});
//
// 		rl.on('close', () => {
// 			resolve(null); // Resolve with null if the pattern is not found in the entire file
// 		});
//
// 		readStream.on('error', (err) => {
// 			reject(err);
// 		});
//
// 		resolve('hello');
// 	});
// }

export async function getValueFromFile(filePath: string, searchString: string): Promise<string> {
	const fileContent = await fs.promises.readFile(filePath, 'utf8');
	const lines = fileContent.split('\n');

	for (const line of lines) {
		if (line.startsWith(searchString)) {
			return line.substring(searchString.length);
		}
	}

	return '';
}

// export function extractValueFromFile(filePath: string, pattern: string): Promise<string | null> {
// 	return new Promise((resolve, reject) => {
// 		fs.readFile(filePath, 'utf8', (err, data) => {
// 			if (err) {
// 				reject(err);
// 				return;
// 			}
//
// 			console.log('File Data:', data); // Log the entire file data for debugging
//
// 			const patternIndex = data.indexOf(pattern);
// 			if (patternIndex !== -1) {
// 				// Extract the value after the pattern
// 				const valueStartIndex = patternIndex + pattern.length;
// 				const valueEndIndex = data.indexOf(' ', valueStartIndex); // Assume values are followed by a space
//
// 				const extractedValue =
// 					valueEndIndex !== -1
// 						? data.substring(valueStartIndex, valueEndIndex)
// 						: data.substring(valueStartIndex);
//
// 				console.log('Extracted Value:', extractedValue); // Log the extracted value
//
// 				resolve(extractedValue);
// 			} else {
// 				resolve(null);
// 			}
// 		});
// 	});
// }

// Extracting user value
// export function extractValueFromFile(filePath: string, pattern: string): Promise<string | null> {
// 	return new Promise((resolve, reject) => {
// 		// Read the file asynchronously
// 		fs.readFile(filePath, 'utf8', (err, data) => {
// 			if (err) {
// 				reject(err);
// 				return;
// 			}
//
// 			// Construct a regular expression using the provided pattern
// 			const regex = new RegExp(`${pattern}=([^&\\s]+)`);
// 			const match = data.match(regex);
//
// 			if (match && match[1]) {
// 				resolve(match[1]);
// 			} else {
// 				resolve(null);
// 			}
// 		});
// 	});
// }
