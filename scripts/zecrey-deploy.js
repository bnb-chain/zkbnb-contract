const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')

async function main() {
    // deploy zns
    const ZNSRegistry = await ethers.getContractFactory('ZNSRegistry');
    const znsRegistry = await ZNSRegistry.deploy();
    await znsRegistry.deployed();

    // deploy zns fifs registrar
    const ZNSFIFSRegistrar = await ethers.getContractFactory('ZNSFIFSRegistrar');
    const znsFIFSRegistrar = await ZNSFIFSRegistrar.deploy();
    await znsFIFSRegistrar.deployed();
    // initialize zns fifs registrar
    const baseNode = namehash.hash('legend');
    const initZnsFifsRegistrarParams = ethers.utils.defaultAbiCoder.encode(['address', 'bytes32'], [znsRegistry.address, baseNode])
    const initZnsFifsTx = await znsFIFSRegistrar.initialize(initZnsFifsRegistrarParams);
    await initZnsFifsTx.wait();
    // deploy governance
    // governance
    const Governance = await ethers.getContractFactory('Governance')
    /*
    uint8 _chainId, uint16 _nativeAssetId, uint16 _maxPendingBlocks
     */
    const governance = await Governance.deploy();
    await governance.deployed();
    const [owner] = await ethers.getSigners();
    const governor = owner.address;
    /*
    address _networkGovernor = abi.decode(initializationParameters, (address));
     */
    const initGovernanceParams = ethers.utils.defaultAbiCoder.encode(['address'], [governor]);
    const initGovernanceTx = await governance.initialize(initGovernanceParams);
    await initGovernanceTx.wait();
    // set committer
    const setCommitterTx = await governance.setValidator(governor, true);
    await setCommitterTx.wait();

    // asset governance
    const AssetGovernance = await ethers.getContractFactory('AssetGovernance')
    /*
    Governance _governance,
    IERC20 _listingFeeToken,
    uint256 _listingFee,
    uint16 _listingCap,
    address _treasury
     */
    const _listingFee = ethers.utils.parseEther('100')
    const _listingCap = 2 ** 16 - 1
    const initAssetGovernanceParams = ethers.utils.defaultAbiCoder.encode(
        ['address', 'address', 'uint256', 'uint16', 'address'],
        [governance.address, governance.address, _listingFee, _listingCap, governor])
    const assetGovernance = await AssetGovernance.deploy()
    await assetGovernance.deployed()
    const initAssetGovernanceTx = await assetGovernance.initialize(initAssetGovernanceParams)
    await initAssetGovernanceTx.wait()
    // set lister
    const setListerTx = await assetGovernance.setLister(governor, true)
    await setListerTx.wait()
    // changeAssetGovernance
    const changeAssetGovernanceTx = await governance.changeAssetGovernance(assetGovernance.address)
    await changeAssetGovernanceTx.wait()

    // deploy verifier
    const Verifier = await ethers.getContractFactory('ZecreyVerifier')
    const verifier = await Verifier.deploy()
    await verifier.deployed()
    // deploy utils
    const Utils = await ethers.getContractFactory("Utils")
    const utils = await Utils.deploy()
    await utils.deployed()
    // deploy zecrey legend
    console.log('start deploy zecrey legend.....')
    const ZecreyLegend = await ethers.getContractFactory('ZecreyLegend', {
        libraries: {
            Utils: utils.address
        }
    })
    const zecreyLegend = await ZecreyLegend.deploy()
    await zecreyLegend.deployed()

    // add controller for zns fifs registrar
    const addControllerTx = await znsFIFSRegistrar.addController(zecreyLegend.address);
    await addControllerTx.wait();

    // deploy additional zecrey legend
    const AdditionalZecreyLegend = await ethers.getContractFactory('AdditionalZecreyLegend')
    const additionalZecreyLegend = await AdditionalZecreyLegend.deploy()
    await additionalZecreyLegend.deployed()

    /*
         (
        address _governanceAddress,
        address _verifierAddress,
        address _additionalZecreylegend,
        address _znsFifsRegistrar,
        bytes32 _genesisAccountRoot
        ) = abi.decode(initializationParameters, (address, address, address, address, bytes32));
    */
    const _genesisAccountRoot = '0x01ef55cdf3b9b0d65e6fb6317f79627534d971fd96c811281af618c0028d5e7a'
    const zecreyInitParams = ethers.utils.defaultAbiCoder.encode(
        ['address', 'address', 'address', 'address', 'bytes32'],
        [
            governance.address,
            verifier.address,
            additionalZecreyLegend.address,
            znsFIFSRegistrar.address,
            _genesisAccountRoot,
        ],
    )
    const zecreyInitTx = await zecreyLegend.initialize(zecreyInitParams)
    await zecreyInitTx.wait()

}

// get the keccak256 hash of a specified string name
// eg: getKeccak256('zecrey') = '0x621eacce7c1f02dbf62859801a97d1b2903abc1c3e00e28acfb32cdac01ab36d'
const getKeccak256 = (name) => {
    return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name))
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });