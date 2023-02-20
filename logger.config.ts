import { ILogObject, Logger } from 'tslog';
import { appendFileSync } from 'fs';

function logToTransport(logObject: ILogObject) {
  appendFileSync(
    'logs.txt',
    logObject.date +
      ' ' +
      logObject.logLevel.toUpperCase() +
      '   ' +
      logObject.argumentsArray.concat().toString() +
      '\n',
  );
}

const log: Logger = new Logger();
log.setSettings({
  type: 'pretty',
  displayFilePath: 'hidden',
  displayFunctionName: false,
  minLevel: 'info',
  dateTimePattern: 'year-month-day hour:minute:second',
});

log.attachTransport(
  {
    silly: logToTransport,
    debug: logToTransport,
    trace: logToTransport,
    info: logToTransport,
    warn: logToTransport,
    error: logToTransport,
    fatal: logToTransport,
  },
  'debug',
);

export default log;
