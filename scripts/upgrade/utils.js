const hardhat = require('hardhat');
const {
  getDeployedAddresses,
  deployDesertVerifier,
  saveConstructorArgumentsForVerify,
} = require('../deploy-keccak256/utils');
const inquirer = require('inquirer');
const chalk = require('chalk');
const { zeroAddress } = require('@nomicfoundation/ethereumjs-util');
const { ethers } = hardhat;

const AddressZero = ethers.constants.AddressZero;
const targetContractsDeployed = {
  governance: AddressZero,
  verifier: AddressZero,
  zkbnb: AddressZero,
};
let targetContracts;

const targetsUpgradeParameter = (upgradeJson) => {
  const zkBNBUpgradeParameter = {
    additionalZkBNB: upgradeJson.additionalZkBNB ? upgradeJson.additionalZkBNB[0] : zeroAddress(),
    desertVerifier: upgradeJson.desertVerifier ? upgradeJson.desertVerifier[0] : zeroAddress(),
  };
  return [
    '0x00',
    '0x00',
    ethers.utils.defaultAbiCoder.encode(
      ['address', 'address'], // newAdditionalZkBNB.addresss, newDesertVerifier.addresss
      [zkBNBUpgradeParameter['additionalZkBNB'], zkBNBUpgradeParameter['desertVerifier']],
    ),
  ];
};

async function getUpgradeableContractImplement() {
  const addrs = getDeployedAddresses('info/addresses.json');
  const contractFactories = await getContractFactories();

  /* ----------------------- current implement contracts ---------------------- */
  const governanceProxy = await contractFactories.Proxy.attach(addrs.governance);
  const verifierProxy = await contractFactories.Proxy.attach(addrs.verifierProxy);
  const zkbnbProxy = await contractFactories.Proxy.attach(addrs.zkbnbProxy);

  const governance = await governanceProxy.getTarget();
  const verifier = await verifierProxy.getTarget();
  const zkbnb = await zkbnbProxy.getTarget();

  return {
    governance,
    verifier,
    zkbnb,
  };
}

async function getContractFactories() {
  const Utils = await ethers.getContractFactory('Utils');
  const utils = await Utils.deploy();
  await utils.deployed();

  return {
    TokenFactory: await ethers.getContractFactory('ZkBNBRelatedERC20'),
    ERC721Factory: await ethers.getContractFactory('ZkBNBRelatedERC721'),
    Governance: await ethers.getContractFactory('Governance'),
    AssetGovernance: await ethers.getContractFactory('AssetGovernance'),
    Verifier: await ethers.getContractFactory('ZkBNBVerifier'),
    ZkBNB: await ethers.getContractFactory('ZkBNB', {
      libraries: {
        Utils: utils.address,
      },
    }),
    DeployFactory: await ethers.getContractFactory('DeployFactory', {
      libraries: {
        Utils: utils.address,
      },
    }),
    DefaultNftFactory: await ethers.getContractFactory('ZkBNBNFTFactory'),
    UpgradeableMaster: await ethers.getContractFactory('UpgradeableMaster'),
    UpgradeGatekeeper: await ethers.getContractFactory('UpgradeGatekeeper'),
    Proxy: await ethers.getContractFactory('Proxy'),
  };
}

async function startUpgrade(owner, upgradeGatekeeper, upgradeGatekeeperActor) {
  const status = await upgradeGatekeeper.upgradeStatus();
  if (status !== 0 /* idle */) {
    console.log(chalk.red(`🙃 Update flow is in progress`));
    return;
  }

  await inquirer
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
        let Utils, TxTypes;
        let utils, txTypes;

        switch (contract) {
          case 'governance':
            Utils = await ethers.getContractFactory('Utils');
            utils = await Utils.deploy();
            await utils.deployed();
            console.log('Utils deployed \t in %s', utils.address);
            targetContractsDeployed.utils = utils.address;

            Governance = await ethers.getContractFactory('Governance', {
              libraries: {
                Utils: utils.address,
              },
            });
            deployContract = await Governance.deploy();
            break;
          case 'verifier':
            ZkBNBVerifier = await ethers.getContractFactory('ZkBNBVerifier');
            deployContract = await ZkBNBVerifier.deploy();
            break;
          case 'zkbnb':
            TxTypes = await ethers.getContractFactory('TxTypes');
            txTypes = await TxTypes.deploy();
            await txTypes.deployed();
            console.log('TxTypes deployed \t in %s', txTypes.address);
            targetContractsDeployed.txTypes = txTypes.address;

            ZkBNB = await ethers.getContractFactory('ZkBNB', {
              libraries: {
                TxTypes: txTypes.address,
              },
            });
            deployContract = await ZkBNB.deploy();

            await inquirer
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

                    // zkBNBUpgradeParameter['additionalZkBNB'] = additionalZkBNB.address;
                    break;
                  case 'Yes only desertVerifier':
                    desertVerifier = await deployDesertVerifier(owner);
                    await desertVerifier.deployed();

                    // zkBNBUpgradeParameter['desertVerifier'] = desertVerifier.address;
                    break;
                  case 'Yes both':
                    AdditionalZkBNB = await ethers.getContractFactory('AdditionalZkBNB');
                    additionalZkBNB = await AdditionalZkBNB.deploy();
                    await additionalZkBNB.deployed();

                    desertVerifier = await deployDesertVerifier(owner);
                    await desertVerifier.deployed();

                    // zkBNBUpgradeParameter['additionalZkBNB'] = additionalZkBNB.address;
                    // zkBNBUpgradeParameter['desertVerifier'] = desertVerifier.address;
                    break;

                  default:
                    break;
                }
                console.log(
                  'zkBNB upgrade parameters: [%s, %s]',
                  additionalZkBNB ? additionalZkBNB.address : AddressZero,
                  desertVerifier ? desertVerifier.address : AddressZero,
                );
                if (additionalZkBNB) {
                  targetContractsDeployed.additionalZkBNB = additionalZkBNB.address;
                }
                if (desertVerifier) {
                  targetContractsDeployed.desertVerifier = desertVerifier.address;
                }
              });
            break;

          default:
            break;
        }
        await deployContract.deployed();
        targetContractsDeployed[contract] = deployContract.address;
        console.log('%s deployed \t in %s', contract.capitalize(), deployContract.address);
      }

      await inquirer
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

          const versionId = Number(await upgradeGatekeeper.versionId());
          console.log(chalk.green('🚚 Start Upgrade'));
          const constructorJson = {};
          for (const item in targetContractsDeployed) {
            constructorJson[item] = [targetContractsDeployed[item]];
          }
          saveConstructorArgumentsForVerify(`info/upgrade-${versionId}.json`, constructorJson);
          const upgradeJson = getDeployedAddresses(`info/upgrade-${versionId}.json`);
          const upgradeParameters = targetsUpgradeParameter(upgradeJson);

          try {
            const tx = await upgradeGatekeeperActor.startUpgrade(
              [targetContractsDeployed.governance, targetContractsDeployed.verifier, targetContractsDeployed.zkbnb],
              upgradeParameters,
            );

            console.log('✅ startUpgrade done. Please check explorer. txid: ', tx.hash);
          } catch (error) {
            console.log('❌ startUpgrade failed. ', error);
          }
        });
    });
}

async function finishUpgrade(upgradeGatekeeper, upgradeGatekeeperActor) {
  const upgradeStatus = await upgradeGatekeeper.upgradeStatus();

  if (upgradeStatus !== 2) {
    console.log(chalk.red('🙃 Already in the preparation stage'));
    return;
  }

  const versionId = await upgradeGatekeeper.versionId();
  const upgradeJson = getDeployedAddresses(`info/upgrade-${versionId}.json`);
  const upgradeParameters = targetsUpgradeParameter(upgradeJson);

  const upgradeTargets = {
    governance: upgradeJson.governance[0],
    verifier: upgradeJson.verifier[0],
    zkbnb: upgradeJson.zkbnb[0],
    upgradeParameters,
  };

  console.log(upgradeTargets);
  await inquirer
    .prompt([
      {
        type: 'confirm',
        name: 'confirm',
        message: 'please comfirm upgrade parameters',
      },
    ])
    .then(async (answers) => {
      if (!answers.confirm) {
        return;
      }
      console.log(chalk.green('🚀 Finish Upgrade'));
      const tx = await upgradeGatekeeperActor.finishUpgrade(upgradeParameters);
      console.log('✅ finishUpgrade done. Please check explorer. txid: ', tx.hash);
    });
}

module.exports = {
  getContractFactories,
  getUpgradeableContractImplement,
  startUpgrade,
  finishUpgrade,
};
