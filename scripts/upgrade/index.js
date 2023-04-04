const hardhat = require('hardhat');
const { getDeployedAddresses, deployDesertVerifier } = require('../deploy-keccak256/utils');
const { getUpgradeableContractImplement } = require('./utils');
const { ethers } = hardhat;

const inquirer = require('inquirer');
const figlet = require('figlet');
const chalk = require('chalk');

const AddressZero = ethers.constants.AddressZero;

let targetContracts;
const addrs = getDeployedAddresses('info/addresses.json');

const targetContractsDeployed = {
  governance: AddressZero,
  verifier: AddressZero,
  zkbnb: AddressZero,
};

const zkBNBUpgradeParameter = {
  additionalZkBNB: AddressZero,
  desertVerifier: AddressZero,
};

Object.defineProperty(String.prototype, 'capitalize', {
  value() {
    return this.charAt(0).toUpperCase() + this.slice(1);
  },
  enumerable: false,
});

function main() {
  console.log(chalk.green(figlet.textSync('zkBNB upgradeable tool')));

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
        choices: ['start', 'preparation', 'cut period(only local)', 'cancel', 'finish', 'rollback'],
      },
    ])
    .then(async (answers) => {
      switch (answers.operator) {
        case 'start':
          start();
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
          finish();
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

async function start() {
  const [owner] = await ethers.getSigners();

  const UpgradeGatekeeper = await ethers.getContractFactory('UpgradeGatekeeper');
  const upgradeGatekeeper = await UpgradeGatekeeper.attach(addrs.upgradeGateKeeper);

  const status = await upgradeGatekeeper.upgradeStatus();
  if (status !== 0 /* idle */) {
    console.log(chalk.red(`🙃 Update flow is in progress`));
    return;
  }

  inquirer
    .prompt([
      {
        type: 'checkbox',
        name: 'target',
        message: 'Which contracts do you want to upgrade?',
        choices: ['governance', 'verifier', 'zkbnb'],

        validate(answer) {
          if (answer.length < 1) {
            return 'You must choose at least one topping.';
          }

          return true;
        },
      },
    ])
    .then(async (answers) => {
      targetContracts = answers.target;
      console.log(chalk.green('🚀 Deploy new contract'));
      for (const contract of targetContracts) {
        let deployContract, additionalZkBNB, desertVerifier;
        let Governance, ZkBNBVerifier, ZkBNB, AdditionalZkBNB;

        const Utils = await ethers.getContractFactory('Utils');
        const utils = await Utils.deploy();
        await utils.deployed();

        switch (contract) {
          case 'governance':
            Governance = await ethers.getContractFactory('Governance');
            deployContract = await Governance.deploy();
            break;
          case 'verifier':
            ZkBNBVerifier = await ethers.getContractFactory('ZkBNBVerifier');
            deployContract = await ZkBNBVerifier.deploy();
            break;
          case 'zkbnb':
            ZkBNB = await ethers.getContractFactory('ZkBNB', {
              libraries: {
                Utils: utils.address,
              },
            });
            deployContract = await ZkBNB.deploy();

            inquirer
              .prompt([
                {
                  type: 'list',
                  name: 'zkbnbParams',
                  message: 'Do you want to update additionalZkBNB and/or desertVerifier addresses?',
                  choices: ['No', 'Yes only additionalZkBNB', 'Yes only desertVerifier', 'Yes both'],
                },
              ])
              .then(async (answer) => {
                switch (answer.zkbnbParams) {
                  case 'No':
                    break;
                  case 'Yes only additionalZkBNB':
                    AdditionalZkBNB = await ethers.getContractFactory('AdditionalZkBNB');
                    additionalZkBNB = await AdditionalZkBNB.deploy();
                    await additionalZkBNB.deployed();

                    zkBNBUpgradeParameter['additionalZkBNB'] = additionalZkBNB.address;
                    break;
                  case 'Yes only desertVerifier':
                    desertVerifier = await deployDesertVerifier(owner);
                    await desertVerifier.deployed();

                    zkBNBUpgradeParameter['desertVerifier'] = desertVerifier.address;
                    break;
                  case 'Yes both':
                    AdditionalZkBNB = await ethers.getContractFactory('AdditionalZkBNB');
                    additionalZkBNB = await AdditionalZkBNB.deploy();
                    await additionalZkBNB.deployed();

                    desertVerifier = await deployDesertVerifier(owner);
                    await desertVerifier.deployed();

                    zkBNBUpgradeParameter['additionalZkBNB'] = additionalZkBNB.address;
                    zkBNBUpgradeParameter['desertVerifier'] = desertVerifier.address;
                    break;

                  default:
                    break;
                }
                console.log('zkBNB upgrade parameters: [%s, %s]', additionalZkBNB.address, desertVerifier.address);
              });
            break;

          default:
            break;
        }
        await deployContract.deployed();
        targetContractsDeployed[contract] = deployContract.address;
        console.log('%s deployed \t in %s', contract.capitalize(), deployContract.address);
      }

      inquirer
        .prompt([
          {
            type: 'confirm',
            name: 'confirm',
            message: 'Above contract will be upgrade. \n Do you want continue?',
          },
        ])
        .then(async (answers) => {
          if (!answers.confirm) {
            return;
          }

          console.log(chalk.green('🚚 Start Upgrade'));
          const tx = await upgradeGatekeeper.startUpgrade([
            targetContractsDeployed.governance,
            targetContractsDeployed.verifier,
            targetContractsDeployed.zkbnb,
          ]);

          const receipt = await tx.wait();
          console.log(chalk.green('✅ Upgrade process started'));

          console.log('🏷️  Current version is %s', receipt.events[0].args.versionId);
        });
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

  // const securityCouncil1 = new ethers.Wallet(
  //   '0x689af8efa8c651a91ad287602527f3af2fe9f6501a7ac4b061667b5a93e037fd',
  //   ethers.provider,
  // );
  // const securityCouncil2 = new ethers.Wallet(
  //   '0xde9be858da4a475276426320d5e9262ecfc3ba460bfac56360bfa6c4c28b4ee0',
  //   ethers.provider,
  // );
  // const securityCouncil3 = new ethers.Wallet(
  //   '0xdf57089febbacf7ba0bc227dafbffa9fc08a93fdc68e1e42411a14efcf23656e',
  //   ethers.provider,
  // );

  // const addrs = getDeployedAddresses('info/addresses.json');

  // const UpgradeableMaster = await ethers.getContractFactory('UpgradeableMaster');
  // const upgradeableMaster = await UpgradeableMaster.attach(addrs.upgradeableMaster);
  // console.log(chalk.green('🚀 Approve Upgrade'));
  // await approve(securityCouncil1);
  // await approve(securityCouncil2);
  // await approve(securityCouncil3);
  // console.log(chalk.green('✅ Approved'));
  // async function approve(security) {
  //   const tx = await upgradeableMaster.connect(security).cutUpgradeNoticePeriod();
  //   const receipt = await tx.wait();
  //   console.log(
  //     'number Of approvals from security council %s',
  //     receipt.events[0].args.numberOfApprovalsFromSecurityCouncil,
  //   );
  // }
}

async function finish() {
  /* ------------------------- Check upgrade status ------------------------ */
  const UpgradeGatekeeper = await ethers.getContractFactory('UpgradeGatekeeper');
  const upgradeGatekeeper = await UpgradeGatekeeper.attach(addrs.upgradeGateKeeper);

  const upgradeStatus = await upgradeGatekeeper.upgradeStatus();

  if (upgradeStatus !== 2) {
    console.log(chalk.red('🙃 Already in the preparation stage'));
    return;
  }
  console.log(chalk.green('🚀 Finish Upgrade'));
  const tx = await upgradeGatekeeper.finishUpgrade([
    '0x00',
    '0x00',
    ethers.utils.defaultAbiCoder.encode(
      ['address', 'address'], // newAdditionalZkBNB.addresss, newDesertVerifier.addresss
      [zkBNBUpgradeParameter['additionalZkBNB'], zkBNBUpgradeParameter['desertVerifier']],
    ),
  ]);
  const receipt = await tx.wait();
  const impls = await getUpgradeableContractImplement();
  console.log('**** New implement Contract ****');
  console.table(impls);
  console.log(chalk.green('✅ Finished'));
  console.log('Current version is %s', receipt.events[1].args.versionId);
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
