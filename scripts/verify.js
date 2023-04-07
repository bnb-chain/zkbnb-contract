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

  for (const key in contracts) {
    const [contractAddress, constructorArgs] = contracts[key];
    if (contractAddress) {
      console.log('[%s] %s', chalk.green(key), chalk.grey(`${bscscanURI}/${contractAddress}#code`));
      await verifyContract(contractAddress, constructorArgs);
    }
  }
}

async function verifyContract(address, constructorArguments) {
  try {
    await hardhat.run('verify:verify', {
      address,
      constructorArguments,
    });
  } catch (error) {
    console.log(chalk.red(error));
  }
}
main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err.message || err);
    process.exit(1);
  });
