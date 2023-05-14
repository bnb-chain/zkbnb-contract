const hardhat = require('hardhat');
const { saveDeployedAddresses, saveConstructorArgumentsForVerify, deployDesertVerifier } = require('./utils');
require('dotenv').config();
const figlet = require('figlet');
const chalk = require('chalk');

const { ethers } = hardhat;
const { SECURITY_COUNCIL_MEMBERS_NUMBER_1, SECURITY_COUNCIL_MEMBERS_NUMBER_2, SECURITY_COUNCIL_MEMBERS_NUMBER_3 } =
  process.env;

const abi = ethers.utils.defaultAbiCoder;

async function main() {
  console.log(chalk.yellow(figlet.textSync('zkBNB Deploy tool')));

  console.log(chalk.green('\t📦 Clean building target...'));
  await hardhat.run('clean');
  await hardhat.run('compile');

  const network = hardhat.network.name;
  const isMainnet = network === 'BSCMainnet';

  const [owner] = await ethers.getSigners();
  const governor = owner.address;

  const contractFactories = await getContractFactories();
  console.log(chalk.blue('🚀 Deploy Contracts:'));

  // Step 1: deploy proxy contract

  // governance
  console.log(chalk.green('\t📦 Governance...'));
  const governance = await contractFactories.Governance.deploy();
  await governance.deployed();
  // verifier
  console.log(chalk.green('\t📦 Verifier...'));
  const verifier = await contractFactories.Verifier.deploy();
  await verifier.deployed();
  // zkbnb
  console.log(chalk.green('\t📦 ZkBNB...'));
  const zkbnb = await contractFactories.ZkBNB.deploy();
  await zkbnb.deployed();
  // UpgradeableMaster
  console.log(chalk.green('\t📦 UpgradeableMaster...'));
  const upgradeableMasterParams = [
    [SECURITY_COUNCIL_MEMBERS_NUMBER_1, SECURITY_COUNCIL_MEMBERS_NUMBER_2, SECURITY_COUNCIL_MEMBERS_NUMBER_3],
    zkbnb.address,
  ];
  const upgradeableMaster = await contractFactories.UpgradeableMaster.deploy(...upgradeableMasterParams);
  await upgradeableMaster.deployed();

  // Step 2: initialize deploy factory and finish deployment

  // deploy DesertVerifier
  console.log(chalk.green('\t📦 DesertVerifier...'));
  const desertVerifier = await deployDesertVerifier(owner);

  // get ERC721
  const ERC721 = await contractFactories.ERC721Factory.deploy('zkBNB', 'zkBNB', '0');
  await ERC721.deployed();
  const _genesisStateRoot = '0x1bb54bd4586b34192cd80ca2b19d3579b68509c2a9302405fa8758ba905765c4';
  const _listingFee = ethers.utils.parseEther('100');
  const _listingCap = 2 ** 16 - 1;
  const BUSDToken = isMainnet
    ? '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56'
    : '0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee';

  // Listing fee should be BUSD
  const _listingToken = BUSDToken;

  // deploy DeployFactory
  console.log(chalk.blue('🚛 Run DeployFactory'));

  // TODO The upgradeableMaster.address parameter is the master of the xxxProxy contract that will be created, so consider whether it needs to be converted to a gnosis owner here
  const deployFactory = await contractFactories.DeployFactory.deploy(
    [
      governance.address,
      verifier.address,
      zkbnb.address,
      governor,
      governor,
      _listingToken,
      desertVerifier.address,
      upgradeableMaster.address,
    ],
    _genesisStateRoot,
    _listingFee,
    _listingCap,
    {
      gasLimit: 13000000,
    },
  );
  await deployFactory.deployed();

  // Get deployed proxy contracts and the gatekeeper contract,
  // they are used for invoking methods.
  const deployFactoryTx = await deployFactory.deployTransaction;
  const deployFactoryTxReceipt = await deployFactoryTx.wait();
  const AddressesInterface = new ethers.utils.Interface([
    'event Addresses(address governance, address assetGovernance, address verifier, address zkbnb, address gatekeeper, address additionalZkBNB)',
  ]);
  // The specified index is the required event.
  // console.log(deployFactoryTxReceipt.logs);
  let event;
  for (const _log of deployFactoryTxReceipt.logs) {
    if (_log.topics[0] == '0xa6713bbaa2d52898013d0b2731295761eeb112eeb1805178987e2490c1a99998') {
      event = AddressesInterface.decodeEventLog('Addresses', _log.data, _log.topics);
    }
  }
  const [
    governanceEntryAddress,
    assetGovernanceEntryAddress,
    verifierEntryAddress,
    zkbnbEntryAddress,
    upgradeGatekeeperEntryAddress,
    additionalZkBNBLogicAddress,
  ] = event;

  const assetGovernance = contractFactories.AssetGovernance.attach(assetGovernanceEntryAddress);

  // BUSD should be added at first place
  const addAssetTx = await assetGovernance.addAsset(BUSDToken);
  await addAssetTx.wait();

  // deploy default nft factory
  console.log(chalk.blue('⚙️ Setting ZkBNB DefaultNftFactory'));
  console.log('\t🚀Deploy DefaultNftFactory...');
  const DefaultNftFactory = await contractFactories.DefaultNftFactory.deploy(
    'zkBNB',
    'zkBNB',
    zkbnbEntryAddress,
    governor,
  );
  await DefaultNftFactory.deployed();

  console.log('\t🔧Set default nft factory...');
  const proxyGovernance = contractFactories.Governance.attach(governanceEntryAddress);
  const setDefaultNftFactoryTx = await proxyGovernance.setDefaultNFTFactory(DefaultNftFactory.address);
  await setDefaultNftFactoryTx.wait();

  // Add validators into governance
  console.log(chalk.blue('📥 Add validators into governance...'));
  if (process.env.VALIDATORS) {
    const validators = process.env.VALIDATORS.split(',');
    for (const validator of validators) {
      await proxyGovernance.setValidator(validator, true);
      console.log(chalk.blue(`\t📦 Added validator ${validator}`));
    }
  }

  console.log(chalk.blue('🔐 Granted permission...'));
  const UPGRADE_GATEKEEPER_ROLE = await upgradeableMaster.UPGRADE_GATEKEEPER_ROLE();
  await upgradeableMaster.grantRole(
    UPGRADE_GATEKEEPER_ROLE,
    upgradeGatekeeperEntryAddress /* upgradeGateKeeper.address */,
  );
  await upgradeableMaster.changeZkBNBAddress(zkbnbEntryAddress /* zkbnb.address */);

  // Save addresses into JSON
  console.log(chalk.blue('📥 Save deployed contract addresses and arguments'));

  saveDeployedAddresses(
    'info/addresses.json',
    Object.assign({
      governance: governanceEntryAddress,
      assetGovernance: assetGovernanceEntryAddress,
      verifierProxy: verifierEntryAddress,
      zkbnbProxy: zkbnbEntryAddress,
      upgradeGateKeeper: upgradeGatekeeperEntryAddress,
      additionalZkBNB: additionalZkBNBLogicAddress,
      ERC721: ERC721.address,
      DefaultNftFactory: DefaultNftFactory.address,
      upgradeableMaster: upgradeableMaster.address,
      utils: contractFactories.Utils.address,
      txTypes: contractFactories.TxTypes.address,
      desertVerifier: desertVerifier.address,
      BUSDToken,
    }),
  );

  // Save contract constructor arguments to JSON for verify
  saveConstructorArgumentsForVerify('info/constructor.json', {
    governanceLogic: [governance.address],
    assetGovernance: [
      assetGovernanceEntryAddress,
      [
        governanceEntryAddress, // governace
        _listingToken,
        _listingFee.toString(),
        _listingCap,
        governor,
      ],
    ],
    utils: [contractFactories.Utils.address],
    txTypes: [contractFactories.TxTypes.address],
    verifierLogic: [verifier.address],
    zkbnbLogic: [zkbnb.address],
    upgradeGateKeeper: [upgradeGatekeeperEntryAddress, [upgradeableMaster.address]],
    additionalZkBNB: [additionalZkBNBLogicAddress],
    desertVerifier: [desertVerifier.address],
    ERC721: [ERC721.address, ['zkBNB', 'zkBNB', 0]],
    DefaultNftFactory: [DefaultNftFactory.address, ['zkBNB', 'zkBNB', zkbnbEntryAddress, governor]],
    upgradeableMaster: [upgradeableMaster.address, upgradeableMasterParams],
    governanceProxy: [governanceEntryAddress, [governance.address, abi.encode(['address'], [deployFactory.address])]],
    verifierProxy: [verifierEntryAddress, [verifier.address, '0x']],
    zkbnbProxy: [
      zkbnbEntryAddress,
      [
        zkbnb.address,
        abi.encode(
          ['address', 'address', 'address', 'address', 'bytes32'],
          [
            governanceEntryAddress,
            verifierEntryAddress,
            additionalZkBNBLogicAddress,
            desertVerifier.address,
            _genesisStateRoot,
          ],
        ),
      ],
    ],
  });
}

async function getContractFactories() {
  const TxTypes = await ethers.getContractFactory('TxTypes');
  const txTypes = await TxTypes.deploy();
  await txTypes.deployed();

  const Utils = await ethers.getContractFactory('Utils');
  const utils = await Utils.deploy();
  await utils.deployed();

  return {
    TokenFactory: await ethers.getContractFactory('ZkBNBRelatedERC20'),
    ERC721Factory: await ethers.getContractFactory('ZkBNBRelatedERC721'),
    Governance: await ethers.getContractFactory('Governance', {
      libraries: {
        Utils: utils.address,
      },
    }),
    AssetGovernance: await ethers.getContractFactory('AssetGovernance'),
    Verifier: await ethers.getContractFactory('ZkBNBVerifier'),
    ZkBNB: await ethers.getContractFactory('ZkBNB', {
      libraries: {
        TxTypes: txTypes.address,
      },
    }),
    DeployFactory: await ethers.getContractFactory('DeployFactory'),
    DefaultNftFactory: await ethers.getContractFactory('ZkBNBNFTFactory'),
    UpgradeableMaster: await ethers.getContractFactory('UpgradeableMaster'),
    Utils: utils,
    TxTypes: txTypes,
  };
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err.message || err);
    process.exit(1);
  });
