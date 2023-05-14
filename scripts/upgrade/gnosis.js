const hardhat = require('hardhat');
const { getDeployedAddresses } = require('../deploy-keccak256/utils');
const { startUpgrade, finishUpgrade } = require('./utils');
const { ethers } = hardhat;
const { EthersAdapter } = require('@safe-global/protocol-kit');
const Safe = require('@safe-global/safe-core-sdk').default;
const { SafeEthersSigner, SafeService } = require('@safe-global/safe-ethers-adapters');
require('dotenv').config();

const inquirer = require('inquirer');
const figlet = require('figlet');
const chalk = require('chalk');

const addrs = getDeployedAddresses('info/addresses.json');

Object.defineProperty(String.prototype, 'capitalize', {
  value() {
    return this.charAt(0).toUpperCase() + this.slice(1);
  },
  enumerable: false,
});

async function main() {
  console.log(chalk.green(figlet.textSync('zkBNB upgradeable tool')));

  const { gnosisUpgradeGatekeeper, upgradeGatekeeper } = await getGnosisupgradeGatekeeper();
  const owner = await upgradeGatekeeper.getMaster();

  if (!hardhat.network.name) {
    console.log(chalk.red(`🙃 Contract not deploy in ${hardhat.network.name}`));
    return;
  }
  inquirer
    .prompt([
      {
        type: 'list',
        name: 'operator',
        message: 'What do you want?',
        choices: ['start', 'preparation', 'cut period', 'cancel', 'finish', 'rollback'],
      },
    ])
    .then(async (answers) => {
      switch (answers.operator) {
        case 'start':
          await startUpgrade(owner, upgradeGatekeeper, gnosisUpgradeGatekeeper);
          console.log(chalk.green('💻 Go to the Safe Web App [https://app.safe.global] to confirm the transaction'));
          break;
        case 'cancel':
          cancel();
          break;
        case 'preparation':
          preparation();
          break;
        case 'cut period':
          cutPeriod();
          break;
        case 'finish':
          await finishUpgrade(upgradeGatekeeper, gnosisUpgradeGatekeeper);
          console.log(chalk.green('💻 Go to the Safe Web App [https://app.safe.global] to confirm the transaction'));
          break;
        case 'rollback':
          inquirer
            .prompt([
              {
                type: 'input',
                name: 'target',
                message:
                  'Please enter the block number when the contract was deployed \nand the script will query the upgrade history:',
                validate(answer) {
                  console.log('🚀 ~ file: index.js:295 ~ validate ~ answer:', answer);
                  if (answer.length < 1) {
                    return 'You must input block number.';
                  }

                  return true;
                },
              },
            ])
            .then(async (answer) => {
              rollback(+answer.target);
            });
          break;

        default:
          break;
      }
    });
}

async function preparation() {
  const { gnosisUpgradeGatekeeper, upgradeGatekeeper } = await getGnosisupgradeGatekeeper();

  const upgradeStatus = await upgradeGatekeeper.upgradeStatus();
  if (upgradeStatus !== 1) {
    console.log(chalk.red('🙃 Not ready for prepare'));
    return;
  }
  await gnosisUpgradeGatekeeper.startPreparation();
  console.log(chalk.green('💻 Go to the Safe Web App [https://app.safe.global] to confirm the transaction'));
}

async function cancel() {
  const { gnosisUpgradeGatekeeper } = await getGnosisupgradeGatekeeper();

  console.log(chalk.green('🚀 Cancel Upgrade'));
  await gnosisUpgradeGatekeeper.cancelUpgrade();
  console.log(chalk.green('💻 Go to the Safe Web App [https://app.safe.global] to confirm the transaction'));
}

async function cutPeriod() {
  console.log(chalk.red('🚀 Please invoke contract function in BSCScan'));
}

async function rollback(startBlockNumber) {
  const { gnosisUpgradeGatekeeper, upgradeGatekeeper } = await getGnosisupgradeGatekeeper();

  const status = await upgradeGatekeeper.upgradeStatus();
  if (status !== 0 /* idle */) {
    console.log(chalk.red(`🙃 Update flow is in progress`));
    return;
  }

  console.log(chalk.green('🚀 Rollback'));
  const versionId = await upgradeGatekeeper.versionId();
  console.log(`current version is ${chalk.red(versionId)}`);

  console.log(chalk.green('🔍 search old version...'));
  let previousVersionTargets;
  // If it is the first version, should get the implementation contract address directly from the proxy contract
  if (versionId == 0) {
    previousVersionTargets = {
      governance: await (await ethers.getContractFactory('Proxy')).attach(addrs.governance).getTarget(),
      verifier: await (await ethers.getContractFactory('Proxy')).attach(addrs.verifierProxy).getTarget(),
      zkbnb: await (await ethers.getContractFactory('Proxy')).attach(addrs.zkbnbProxy).getTarget(),
    };
  } else {
    const filter = upgradeGatekeeper.filters.UpgradeComplete(versionId - 1);
    const event = await upgradeGatekeeper.queryFilter(filter, startBlockNumber - 1, startBlockNumber + 100);
    const targets = event[0].args.newTargets;
    previousVersionTargets = {
      governance: targets[0],
      verifier: targets[1],
      zkbnb: targets[2],
    };
  }

  console.log(chalk.green('🚚 Start rollback'));

  console.log('**** Old implement Contract ****');
  console.table(previousVersionTargets);
  console.log('********************************');

  inquirer
    .prompt([
      {
        type: 'confirm',
        name: 'confirm',
        message: 'The contract will be rolled back to the previous version. \n Do you want continue?',
      },
    ])
    .then(async (answers) => {
      if (!answers.confirm) {
        return;
      }

      console.log(chalk.green('✅ rollback process started'));
      await gnosisUpgradeGatekeeper.startUpgrade([
        previousVersionTargets.governance,
        previousVersionTargets.verifier,
        previousVersionTargets.zkbnb,
      ]);
      console.log(chalk.green('💻 Go to the Safe Web App [https://app.safe.global] to confirm the transaction'));
      console.log('after that, you still need to do preparation and finish step.');
    });
}

async function getGnosisupgradeGatekeeper() {
  const UpgradeGatekeeper = await ethers.getContractFactory('UpgradeGatekeeper');
  const upgradeGatekeeper = await UpgradeGatekeeper.attach(addrs.upgradeGateKeeper);
  const owner = await upgradeGatekeeper.getMaster();

  const signerOrProvider = await ethers.getSigner();
  const ethAdapter = new EthersAdapter({
    ethers,
    signerOrProvider,
  });

  const safe = await Safe.create({
    ethAdapter,
    safeAddress: owner,
  });

  // https://docs.safe.global/learn/safe-core/safe-core-api/available-services
  const safeService = new SafeService(process.env.GNOSIS_SERVICE);

  const gnosisSigner = new SafeEthersSigner(safe, safeService, signerOrProvider);
  const gnosisUpgradeGatekeeper = upgradeGatekeeper.connect(gnosisSigner);

  return {
    gnosisUpgradeGatekeeper,
    upgradeGatekeeper,
  };
}

main();
