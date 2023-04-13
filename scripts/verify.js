const hardhat = require('hardhat');
const { getDeployedAddresses } = require('./deploy-keccak256/utils');

const figlet = require('figlet');
const chalk = require('chalk');

const contracts = getDeployedAddresses('info/constructor.json');

Object.defineProperty(String.prototype, 'capitalize', {
  value() {
    return this.charAt(0).toUpperCase() + this.slice(1);
  },
  enumerable: false,
});

async function main() {
  console.log(chalk.blue(figlet.textSync('zkBNB verify contract tool')));
  const isMainnet = hardhat.network.name === 'BSCMainnet';
  const bscscanURI = isMainnet ? 'https://bscscan.com/address/' : 'https://testnet.bscscan.com/address';

  if (!hardhat.network.name) {
    console.log(chalk.red(`🙃 Contract not deploy in ${hardhat.network.name}`));
    return;
  }
  console.log(chalk.green('🔎 Validating contracts： \n'));

  const results = [];
  for (const key in contracts) {
    const [contractAddress, constructorArgs] = contracts[key];
    if (contractAddress) {
      console.log('[%s] %s', chalk.yellow(key), chalk.grey(`${bscscanURI}/${contractAddress}#code`));
      results.push(await verifyContract(key, contractAddress, constructorArgs));
    }
  }
  for (const { key, address, result, reason } of results) {
    if (result) {
      console.log('✅[%s] %s', chalk.green(key), chalk.grey(`${bscscanURI}/${address}#code`));
    } else {
      console.log('❌[%s] %s\n %s', chalk.red(key), chalk.grey(`${bscscanURI}/${address}#code`), chalk.red(reason));
    }
  }
  console.log('⚠️ %s', chalk.yellow('proxy need to verify manually'));
}

async function verifyContract(key, address, constructorArguments) {
  let result = false;
  let reason;
  try {
    await hardhat.run('verify:verify', {
      address,
      constructorArguments,
    });
    result = true;
  } catch (error) {
    // console.log(chalk.red(error));
    if (
      error.toString().includes('Contract source code already verified') ||
      error.toString().includes('Already Verified')
    ) {
      result = true;
    } else {
      reason = error;
    }
  }
  return {
    key,
    address,
    result,
    reason,
  };
}
main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err.message || err);
    process.exit(1);
  });
