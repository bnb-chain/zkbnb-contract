const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')

async function main() {
    // deploy zns
    const ZNSRegistry = await ethers.getContractFactory('ZNSRegistry');
    const znsRegistry = await ZNSRegistry.deploy();
    await znsRegistry.deployed();

    // deploy zns resolver
    const PublicResolver = await ethers.getContractFactory('PublicResolver');
    const publicResolver = await PublicResolver.deploy();
    await publicResolver.deployed()
    const initResolverParams = ethers.utils.defaultAbiCoder.encode(['address'], [znsRegistry.address])
    const initResolverTx = await publicResolver.initialize(initResolverParams);
    await initResolverTx.wait();
    // deploy zns controller
    console.log('start ZNSController...')
    const ZNSController = await ethers.getContractFactory('ZNSController');
    const znsController = await ZNSController.deploy();
    await znsController.deployed();

    const baseNode = namehash.hash('legend');
    // initialize zns controller
    const initZnsControllerParams = ethers.utils.defaultAbiCoder.encode(['address', 'bytes32'], [znsRegistry.address, baseNode])
    const initZnsControllerTx = await znsController.initialize(initZnsControllerParams);
    await initZnsControllerTx.wait();

    // set base node owner
    /*
        bytes32 _node,
        bytes32 _label,
        address _owner,
        bytes32 _pubKey
     */
    const legendNode = getKeccak256('legend')
    const setBaseNodeTx = await znsRegistry.setSubnodeOwner(
        ethers.constants.HashZero,
        legendNode,
        znsController.address,
        ethers.constants.HashZero,
    )
    await setBaseNodeTx.wait()
    // deploy governance
    console.log('start Governance...')
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

    // ERC20
    const TokenFactory = await ethers.getContractFactory('ZecreyRelatedERC20')
    const totalSupply = ethers.utils.parseEther('100000000')
    const LEGToken = await TokenFactory.deploy(totalSupply, 'LEG', 'LEG')
    await LEGToken.deployed()
    const REYToken = await TokenFactory.deploy(totalSupply, 'REY', 'REY')
    await REYToken.deployed()

    // asset governance
    console.log('start AssetGovernance...')
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
    const _treasuryAccountIndex = 0
    const _feeRate = 30
    const _treasuryRate = 5
    const assetGovernance = await AssetGovernance.deploy(
        governance.address, LEGToken.address, _listingFee, _listingCap, governor, _feeRate, _treasuryAccountIndex, _treasuryRate
    )
    await assetGovernance.deployed()
    // set lister
    const setListerTx = await assetGovernance.setLister(governor, true)
    await setListerTx.wait()
    // changeAssetGovernance
    const changeAssetGovernanceTx = await governance.changeAssetGovernance(assetGovernance.address)
    await changeAssetGovernanceTx.wait()

    // add asset
    var addAssetTx = await assetGovernance.addAsset(LEGToken.address)
    await addAssetTx.wait()
    addAssetTx = await assetGovernance.addAsset(REYToken.address)
    await addAssetTx.wait()

    // deploy verifier
    console.log('start Verifier...')
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
    const zecreyLegend = await ZecreyLegend.deploy({
        gasLimit: 8000000,
    })
    await zecreyLegend.deployed()

    // add controller for zns fifs registrar
    const addControllerTx = await znsController.addController(zecreyLegend.address);
    await addControllerTx.wait();

    const isController = await znsController.controllers(zecreyLegend.address)
    console.log(isController)

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
        ['address', 'address', 'address', 'address', 'address', 'bytes32'],
        [
            governance.address,
            verifier.address,
            additionalZecreyLegend.address,
            znsController.address,
            publicResolver.address,
            _genesisAccountRoot,
        ],
    )
    const zecreyInitTx = await zecreyLegend.initialize(zecreyInitParams)
    await zecreyInitTx.wait()

    console.log('zns:', znsRegistry.address)
    console.log('zns resolver:', publicResolver.address)
    console.log('zns controller:', znsController.address)
    console.log('asset governance:', assetGovernance.address)
    console.log('governance:', governance.address)
    console.log('verifier:', verifier.address)
    console.log('utils:', utils.address)
    console.log('zecrey legend:', zecreyLegend.address)
    console.log('additional zecrey legend:', additionalZecreyLegend.address)
    console.log('LEG BEP20:', LEGToken.address)
    console.log('REY BEP20:', REYToken.address)

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