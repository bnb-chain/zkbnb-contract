const hardhat = require('hardhat');
const { getDeployedAddresses } = require('../deploy-keccak256/utils');
const { startUpgrade, finishUpgrade } = require('./utils');
const { ethers } = hardhat;

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

  if (!hardhat.network.name) {
    console.log(chalk.red(`🙃 Contract not deploy in ${hardhat.network.name}`));
    return;
  }

  const UpgradeGatekeeper = await ethers.getContractFactory('UpgradeGatekeeper');
  const upgradeGatekeeper = await UpgradeGatekeeper.attach(addrs.upgradeGateKeeper);
  const [owner] = await ethers.getSigners();

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
          startUpgrade(owner, upgradeGatekeeper, upgradeGatekeeper);
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
          finishUpgrade(upgradeGatekeeper, upgradeGatekeeper);
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
  const UpgradeGatekeeper = await ethers.getContractFactory('UpgradeGatekeeper');
  const upgradeGatekeeper = await UpgradeGatekeeper.attach(addrs.upgradeGateKeeper);

  const upgradeStatus = await upgradeGatekeeper.upgradeStatus();

  if (upgradeStatus !== 1) {
    console.log(chalk.red('🙃 Not ready for prepare'));
    return;
  }
  const tx = await upgradeGatekeeper.startPreparation();
  const receipt = await tx.wait();
  console.log('✅ Prepare upgrade...');
  console.log('Current version is %s', receipt.events[0].args.versionId);
}

async function cancel() {
  const UpgradeGatekeeper = await ethers.getContractFactory('UpgradeGatekeeper');
  const upgradeGatekeeper = await UpgradeGatekeeper.attach(addrs.upgradeGateKeeper);

  console.log(chalk.green('🚀 Cancel Upgrade'));
  await upgradeGatekeeper.cancelUpgrade();
  console.log(chalk.green('✅ Cancel Upgrade'));
}

async function cutPeriod() {
  console.log(chalk.red('🚀 Please invoke contract function in BSCScan'));

  const securityCouncil1 = new ethers.Wallet('', ethers.provider);
  const securityCouncil2 = new ethers.Wallet('', ethers.provider);
  const securityCouncil3 = new ethers.Wallet('', ethers.provider);

  const addrs = getDeployedAddresses('info/addresses.json');

  const UpgradeableMaster = await ethers.getContractFactory('UpgradeableMaster');
  const upgradeableMaster = await UpgradeableMaster.attach(addrs.upgradeableMaster);
  console.log(chalk.green('🚀 Approve Upgrade'));

  const startTimestamp = await upgradeableMaster.upgradeStartTimestamp();

  await approve(securityCouncil1);
  await approve(securityCouncil2);
  await approve(securityCouncil3);
  console.log(chalk.green('✅ Approved'));

  async function approve(security) {
    const tx = await upgradeableMaster.connect(security).cutUpgradeNoticePeriod(startTimestamp);
    const receipt = await tx.wait();
    console.log(
      'number Of approvals from security council %s',
      receipt.events[0].args.numberOfApprovalsFromSecurityCouncil,
    );
  }
}

async function rollback(startBlockNumber) {
  const UpgradeGatekeeper = await ethers.getContractFactory('UpgradeGatekeeper');
  const upgradeGatekeeper = await UpgradeGatekeeper.attach(addrs.upgradeGateKeeper);

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
    const event = await upgradeGatekeeper.queryFilter(filter, startBlockNumber, startBlockNumber + 5000);
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

      const tx = await upgradeGatekeeper.startUpgrade([
        previousVersionTargets.governance,
        previousVersionTargets.verifier,
        previousVersionTargets.zkbnb,
      ]);

      const receipt = await tx.wait();
      console.log(chalk.green('✅ rollback process started'));
      console.log('🏷️  Current version is %s', receipt.events[0].args.versionId);
    });
}

main();
