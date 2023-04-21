import * as fs from 'fs';
import * as path from 'path';
import * as csv from 'fast-csv';
import log from '../../logger.config';

export interface TokenAddressRow {
  Token: string;
  Address: string;
}

export async function readAddressesFromFile(folder: string, file: string) {
  return new Promise<Map<string, string>>((resolve, reject) => {
    //Fail if the file does not exist
    if (!fs.existsSync(path.resolve(folder, file))) {
      log.error('Cannot find file at path: ' + path.resolve(folder, file));
      reject('Error reading file');
    }
    const rows: TokenAddressRow[] = [];
    log.info('Started reading');
    fs.createReadStream(path.resolve(folder, file))
      .pipe(csv.parse<TokenAddressRow, TokenAddressRow>({ headers: true }))
      .on('error', (error) => log.error(error))
      .on('data', (row) => {
        log.debug(`Read row `, row);
        rows.push(row);
      })
      .on('end', (rowCount) => {
        log.info(`Parsed ${rowCount} rows`);
        resolve(convertRowsToMap(rows));
      });
  });
}

function convertRowsToMap(rows: TokenAddressRow[]): Map<string, string> {
  const map = new Map<string, string>();
  for (const row of rows) {
    if (map.has(row.Token)) {
      log.error(`Duplicate token ${row.Token} in file`);
      process.exit(1);
    }
    map.set(row.Token, row.Address);
  }
  return map;
}
