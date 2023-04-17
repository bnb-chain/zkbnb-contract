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

  // deploy Poseidon contracts and DesertVerifier
  console.log(chalk.green('\t📦 DesertVerifier...'));
  const desertVerifier = await deployDesertVerifier(owner);

  // prepare deploy params
  // get ERC20s
  console.log(chalk.blue('🔧 prepare deploy params'));
  let tokens;
  if (isMainnet) {
    tokens = [
      '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56', // BUSD mainnet
      '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c', //BTC
      '0x2170Ed0880ac9A755fd29B2688956BD959F933F8', // ETH
    ];
  } else {
    console.log(chalk.green('\t🚀 Deploy Mock Tokens for Testnet'));
    const totalSupply = ethers.utils.parseEther('100000000');
    const BUSDToken = await contractFactories.TokenFactory.deploy(totalSupply, 'BUSD', 'BUSD');
    await BUSDToken.deployed();
    const LEGToken = await contractFactories.TokenFactory.deploy(totalSupply, 'LEG', 'LEG');
    await LEGToken.deployed();
    const REYToken = await contractFactories.TokenFactory.deploy(totalSupply, 'REY', 'REY');
    await REYToken.deployed();

    tokens = [BUSDToken.address, LEGToken.address, REYToken.address];
  }

  // get ERC721
  const ERC721 = await contractFactories.ERC721Factory.deploy('zkBNB', 'zkBNB', '0');
  await ERC721.deployed();
  const _genesisStateRoot = '0x1bb54bd4586b34192cd80ca2b19d3579b68509c2a9302405fa8758ba905765c4';
  const _listingFee = ethers.utils.parseEther('100');
  const _listingCap = 2 ** 16 - 1;
  const _listingToken = tokens[0]; // tokens[0] is BUSD
  // deploy DeployFactory
  console.log(chalk.blue('🚛 Run DeployFactory'));
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
    { gasLimit: 13000000 },
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
  const event = AddressesInterface.decodeEventLog(
    'Addresses',
    deployFactoryTxReceipt.logs[6].data,
    deployFactoryTxReceipt.logs[6].topics,
  );
  const [
    governanceEntryAddress,
    assetGovernanceEntryAddress,
    verifierEntryAddress,
    zkbnbEntryAddress,
    upgradeGatekeeperEntryAddress,
    additionalZkBNBEntryAddress,
  ] = event;

  const assetGovernance = contractFactories.AssetGovernance.attach(assetGovernanceEntryAddress);

  // deploy default nft factory
  console.log(chalk.blue('⚙️ Setting ZkBNB DefaultNftFactory'));
  console.log('\t🚀Deploy DefaultNftFactory...');
  const DefaultNftFactory = await contractFactories.DefaultNftFactory.deploy(
    'zkBNB',
    'zkBNB',
    zkbnbEntryAddress,
    owner.address,
  );
  await DefaultNftFactory.deployed();

  console.log('\t🔧Set default nft factory...');
  const proxyGovernance = contractFactories.Governance.attach(governanceEntryAddress);
  const setDefaultNftFactoryTx = await proxyGovernance.setDefaultNFTFactory(DefaultNftFactory.address);
  await setDefaultNftFactoryTx.wait();
  console.log(chalk.blue('🚀 Set zkBNB address for governance...'));
  const setZkBNBAddressTx = await proxyGovernance.setZkBNBAddress(zkbnbEntryAddress);
  await setZkBNBAddressTx.wait();
  // Add validators into governance
  console.log(chalk.blue('📥 Add validators into governance...'));
  if (process.env.VALIDATORS) {
    const validators = process.env.VALIDATORS.split(',');
    for (const validator of validators) {
      await proxyGovernance.setValidator(validator, true);
      console.log(chalk.blue(`\t📦 Added validator ${validator}`));
    }
  }

  // Add baseURI into governance
  console.log(chalk.blue('📥 Add baseURI into governance...'));
  const baseURIs = [[0, 'ipfs://f01701220']];
  for (const [type, baseURI] of baseURIs) {
    await proxyGovernance.updateBaseURI(type, baseURI);
    console.log(chalk.blue(`\t🔧 Added baseURI ${type}:${baseURI}`));
  }

  // Add tokens into assetGovernance
  // add asset
  console.log(chalk.blue('📥 Add tokens into assetGovernance asset list...'));
  for (const token of tokens) {
    const addAssetTx = await assetGovernance.addAsset(token);
    await addAssetTx.wait();
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
  const ERC20ForTestnet = isMainnet
    ? {}
    : {
        BUSDToken: tokens[0],
        LEGToken: tokens[1],
        REYToken: tokens[2],
      };
  saveDeployedAddresses(
    'info/addresses.json',
    Object.assign(
      {
        governance: governanceEntryAddress,
        assetGovernance: assetGovernanceEntryAddress,
        verifierProxy: verifierEntryAddress,
        zkbnbProxy: zkbnbEntryAddress,
        upgradeGateKeeper: upgradeGatekeeperEntryAddress,
        additionalZkBNB: additionalZkBNBEntryAddress,
        ERC721: ERC721.address,
        DefaultNftFactory: DefaultNftFactory.address,
        upgradeableMaster: upgradeableMaster.address,
        utils: contractFactories.Utils.address,
      },
      ERC20ForTestnet,
    ),
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
        0,
      ],
    ],
    utils: [contractFactories.Utils.address],
    verifierLogic: [verifier.address],
    zkbnbLogic: [zkbnb.address],
    upgradeGateKeeper: [upgradeGatekeeperEntryAddress, [upgradeableMaster.address]],
    additionalZkBNB: [additionalZkBNBEntryAddress],
    ERC721: [ERC721.address, ['zkBNB', 'zkBNB', 0]],
    DefaultNftFactory: [DefaultNftFactory.address, ['zkBNB', 'zkBNB', zkbnbEntryAddress, owner.address]],
    upgradeableMaster: [upgradeableMaster.address, upgradeableMasterParams],
    governanceProxy: [governanceEntryAddress, [governance.address, abi.encode(['address'], [deployFactory.address])]],
    verifierProxy: [verifierEntryAddress],
    zkbnbProxy: [zkbnbEntryAddress],
  });
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
    DeployFactory: await ethers.getContractFactory('DeployFactory'),
    DefaultNftFactory: await ethers.getContractFactory('ZkBNBNFTFactory'),
    UpgradeableMaster: await ethers.getContractFactory('UpgradeableMaster'),
    Utils: utils,
  };
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err.message || err);
    process.exit(1);
  });
