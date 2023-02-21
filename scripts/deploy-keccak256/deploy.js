const hardhat = require('hardhat');
const namehash = require('eth-ens-namehash');
const fs = require('fs');
const { getKeccak256, saveDeployedAddresses, saveConstructorArgumentsForVerify } = require('./utils');
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
  //  Step 1: deploy zns registry
  console.log(chalk.blue('🚀 Deploy Contracts:'));
  console.log(chalk.green('\t📦 ZNS registry...'));
  const znsRegistry = await contractFactories.ZNSRegistry.deploy();
  await znsRegistry.deployed();

  // Step 2: deploy proxy contract
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
  // ZNS controller
  console.log(chalk.green('\t📦 ZNSController...'));
  const znsController = await contractFactories.ZNSController.deploy();
  await znsController.deployed();
  // ZNS resolver
  console.log(chalk.green('\t📦 ZNSResolver...'));
  const znsResolver = await contractFactories.ZNSResolver.deploy();
  await znsResolver.deployed();
  // UpgradeableMaster
  console.log(chalk.green('\t📦 UpgradeableMaster...'));
  const upgradeableMasterParams = [
    [SECURITY_COUNCIL_MEMBERS_NUMBER_1, SECURITY_COUNCIL_MEMBERS_NUMBER_2, SECURITY_COUNCIL_MEMBERS_NUMBER_3],
    zkbnb.address,
  ];
  const upgradeableMaster = await contractFactories.UpgradeableMaster.deploy(...upgradeableMasterParams);
  await upgradeableMaster.deployed();

  // Step 3: initialize deploy factory and finish deployment
  // deploy price oracle
  console.log(chalk.green('\t📦 Deploy PriceOracleV1...'));
  const priceOracle = await contractFactories.ZNSPriceOracle.deploy(ethers.utils.parseEther('0.05'));
  await priceOracle.deployed();

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
  const ERC721 = await contractFactories.ERC721Factory.deploy('ZkBNB', 'ZkBNB', '0');
  await ERC721.deployed();
  const _genesisAccountRoot = '0x18195ae3b8f5962236067a051c3a5f697a19de8442849677dbbee328107cca81';
  const _listingFee = ethers.utils.parseEther('100');
  const _listingCap = 2 ** 16 - 1;
  const _listingToken = tokens[0]; // tokens[0] is BUSD
  const baseNode = namehash.hash('zkbnb');
  // deploy DeployFactory
  console.log(chalk.blue('🚛 Run DeployFactory'));
  const deployFactory = await contractFactories.DeployFactory.deploy(
    [
      governance.address,
      verifier.address,
      zkbnb.address,
      znsController.address,
      znsResolver.address,
      governor,
      governor,
      _listingToken,
      znsRegistry.address,
      priceOracle.address,
      upgradeableMaster.address,
    ],
    _genesisAccountRoot,
    _listingFee,
    _listingCap,
    baseNode,
    { gasLimit: 13000000 },
  );
  await deployFactory.deployed();

  // Get deployed proxy contracts and the gatekeeper contract,
  // they are used for invoking methods.
  const deployFactoryTx = await deployFactory.deployTransaction;
  const deployFactoryTxReceipt = await deployFactoryTx.wait();
  const AddressesInterface = new ethers.utils.Interface([
    'event Addresses(address governance, address assetGovernance, address verifier, address znsController, address znsResolver, address zkbnb, address gatekeeper, address additionalZkBNB)',
  ]);
  // The specified index is the required event.
  // console.log(deployFactoryTxReceipt.logs)
  const event = AddressesInterface.decodeEventLog(
    'Addresses',
    deployFactoryTxReceipt.logs[11].data,
    deployFactoryTxReceipt.logs[11].topics,
  );
  // Get inner contract proxy address
  // console.log(event)
  const znsControllerProxy = contractFactories.ZNSController.attach(event[3]);
  const assetGovernance = contractFactories.AssetGovernance.attach(event[1]);

  // deploy default nft factory
  console.log(chalk.blue('⚙️ Setting ZkBNB DefaultNftFactory'));
  console.log('\t🚀Deploy DefaultNftFactory...');
  const DefaultNftFactory = await contractFactories.DefaultNftFactory.deploy(
    'ZkBNB',
    'ZkBNB',
    'ipfs://f01701220',
    event[5],
    owner.address,
  );
  await DefaultNftFactory.deployed();

  console.log('\t🔧Set default nft factory...');
  const proxyGovernance = contractFactories.Governance.attach(event[0]);
  const setDefaultNftFactoryTx = await proxyGovernance.setDefaultNFTFactory(DefaultNftFactory.address);
  await setDefaultNftFactoryTx.wait();
  console.log(chalk.blue('🚀 Set zkBNB address for governance...'));
  const setZkBNBAddressTx = await proxyGovernance.setZkBNBAddress(event[5]);
  await setZkBNBAddressTx.wait();

  // Add tokens into assetGovernance
  // add asset
  console.log(chalk.blue('📥 Add tokens into assetGovernance asset list...'));
  for (const token of tokens) {
    const addAssetTx = await assetGovernance.addAsset(token);
    await addAssetTx.wait();
  }
  const proxyGovernance = contractFactories.Governance.attach(event[0]);
  // Add validators into governance
  console.log(chalk.blue('📥 Add validators into governance...'));
  if (process.env.VALIDATORS) {
    const validators = process.env.VALIDATORS.split(',');
    for (const validator of validators) {
      await proxyGovernance.setValidator(validator, true);
      console.log(chalk.blue(`\t📦 Added validator ${validator}`));
    }
  }

  // Step 4: register zns base node
  console.log(chalk.blue('📋 Register ZNS base node...'));
  const rootNode = '0x0000000000000000000000000000000000000000000000000000000000000000';
  const baseNodeLabel = getKeccak256('zkbnb'); // keccak256('zkbnb');
  const setBaseNodeTx = await znsRegistry.setSubnodeOwner(
    rootNode,
    baseNodeLabel,
    znsControllerProxy.address,
    ethers.constants.HashZero,
    ethers.constants.HashZero,
  );
  await setBaseNodeTx.wait();

  console.log(chalk.blue('🔐 Granted permission...'));
  const UPGRADE_GATEKEEPER_ROLE = await upgradeableMaster.UPGRADE_GATEKEEPER_ROLE();
  await upgradeableMaster.grantRole(UPGRADE_GATEKEEPER_ROLE, event[6] /* upgradeGateKeeper.address */);
  await upgradeableMaster.changeZkBNBAddress(event[5] /* zkbnb.address */);

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
        governance: event[0],
        assetGovernance: event[1],
        verifierProxy: event[2],
        znsControllerProxy: event[3],
        znsResolverProxy: event[4],
        zkbnbProxy: event[5],
        upgradeGateKeeper: event[6],
        additionalZkBNB: event[7],
        ERC721: ERC721.address,
        znsPriceOracle: priceOracle.address,
        DefaultNftFactory: DefaultNftFactory.address,
        upgradeableMaster: upgradeableMaster.address,
        utils: contractFactories.Utils.address,
      },
      ERC20ForTestnet,
    ),
  );

  // Save contract constructor arguments to JSON for verify
  saveConstructorArgumentsForVerify('info/constructor.json', {
    proxy: [event[0], [abi.encode(['address'], [deployFactory.address])]],
    governance: [governance.address],
    assetGovernance: [
      event[1],
      [
        governance.address, // governace
        _listingToken,
        _listingFee.toString(),
        _listingCap,
        governor,
        0,
      ],
    ],
    utils: [contractFactories.Utils.address],
    verifier: [verifier.address],
    znsController: [znsController.address],
    znsResolver: [znsResolver.address],
    zkbnb: [zkbnb.address],
    upgradeGateKeeper: [upgradeableMaster.address],
    additionalZkBNB: [event[7]],
    ERC721: [],
    znsPriceOracle: [],
    DefaultNftFactory: [],
    upgradeableMaster: [upgradeableMaster.address, upgradeableMasterParams],
  });
}

async function getContractFactories() {
  const Utils = await ethers.getContractFactory('Utils');
  const utils = await Utils.deploy();
  await utils.deployed();

  return {
    TokenFactory: await ethers.getContractFactory('ZkBNBRelatedERC20'),
    ERC721Factory: await ethers.getContractFactory('ZkBNBRelatedERC721'),
    ZNSRegistry: await ethers.getContractFactory('ZNSRegistry'),
    ZNSResolver: await ethers.getContractFactory('PublicResolver'),
    ZNSPriceOracle: await ethers.getContractFactory('PriceOracleV1'),
    ZNSController: await ethers.getContractFactory('ZNSController'),
    Governance: await ethers.getContractFactory('Governance'),
    AssetGovernance: await ethers.getContractFactory('AssetGovernance'),
    Verifier: await ethers.getContractFactory('ZkBNBVerifier'),
    ZkBNB: await ethers.getContractFactory('ZkBNB'),
    DeployFactory: await ethers.getContractFactory('DeployFactory', {
      libraries: {
        Utils: utils.address,
      },
    }),
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
