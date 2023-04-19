import { writeToPath } from '@fast-csv/format';
import * as path from 'path';
import * as fs from 'fs';
import log from '../../logger.config';

export async function writeToFile(folder: string, file: string, rows: string[][]) {
  //Create foldre if it does not exist
  if (!fs.existsSync(folder)) {
    fs.mkdirSync(folder, { recursive: true });
  }
  writeToPath(path.resolve(folder, file), rows)
    .on('error', (err) => log.error(`Error writing info to file ${path.resolve(folder, file)}`))
    .on('finish', () => log.info(`Done writing info to file ${path.resolve(folder, file)}`));
}
