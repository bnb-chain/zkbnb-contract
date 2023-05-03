const hardhat = require('hardhat');
require('dotenv').config();
const figlet = require('figlet');
const chalk = require('chalk');
const { readAddressesFromFile } = require('../CSVHelpers/readAddressesFromFile');
const { getContractFactories } = require('../upgrade/utils');
const { getDeployedAddresses } = require('./utils');
const { ethers } = hardhat;
const abi = ethers.utils.defaultAbiCoder;

async function main() {
  console.log(chalk.yellow(figlet.textSync('Asset addition tool')));
  const network = hardhat.network.name;
  const isMainnet = network === 'BSCMainnet';
  console.log(chalk.green('Network: ' + network));

  let tokenToAddressMap;
  if (isMainnet) {
    //Load top 100 by market cap tokens from CMC in BNBChain Mainnet
    tokenToAddressMap = await readAddressesFromFile('csv', 'mainnetTokenAddresses.csv');
  } else {
    //Load some popular tokens from BSC Testnet
    tokenToAddressMap = await readAddressesFromFile('csv', 'testnetTokenAddresses.csv');
  }
  //Get deployed asset governance contract address in Mainnet/ Testnet from "info/addresses.json"
  const addrs = getDeployedAddresses('info/addresses.json');
  const AssetGovernance = await ethers.getContractFactory('AssetGovernance');
  const assetGovernance = await AssetGovernance.attach(addrs.assetGovernance);

  console.log(chalk.blue('📥 Add tokens into assetGovernance asset list...'));
  for (const [token, address] of tokenToAddressMap) {
    if (token === 'BUSD') {
      console.log('BUSD is already added when deploying assetGovernance contract. So skipping it.');
      continue;
    }
    if (token === 'WBNB') {
      console.log('Allowing Wrapped BNB to add into assets as BEP-20 instead of native');
    }
    console.log(token + ' = ' + address);
    const addAssetTx = await assetGovernance.addAsset(address);
    await addAssetTx.wait();
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err.message || err);
    process.exit(1);
  });
