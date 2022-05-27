const {expect} = require("chai");
const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')

describe("Zecrey-Legend contract", function () {
    describe('RegisterZNS', function () {
        it("register", async function () {
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
            // deploy zns price oracle
            const ZNSPriceOracle = await ethers.getContractFactory('StablePriceOracle');
            const rentPrices = [0, 1, 2]
            const znsPriceOracle = await ZNSPriceOracle.deploy(rentPrices);
            await znsPriceOracle.deployed();
            // deploy zns controller
            const ZNSController = await ethers.getContractFactory('ZNSController');
            const znsController = await ZNSController.deploy();
            await znsController.deployed();
            // initialize zns controller
            const baseNode = namehash.hash('legend');
            const initZnsControllerParams = ethers.utils.defaultAbiCoder.encode(['address', 'address', 'bytes32'], [znsRegistry.address, znsPriceOracle.address, baseNode])
            const initZnsControllerTx = await znsController.initialize(initZnsControllerParams);
            await initZnsControllerTx.wait();

            const legendNode = getKeccak256('legend')
            const setBaseNodeTx = await znsRegistry.setSubnodeOwner(
                ethers.constants.HashZero,
                legendNode,
                znsController.address,
                ethers.constants.HashZero,
            )
            await setBaseNodeTx.wait()
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

            const TokenFactory = await ethers.getContractFactory('ZecreyRelatedERC20')
            const token = await TokenFactory.deploy(10000, '', '')
            await token.deployed()

            const _listingFee = ethers.utils.parseEther('100')
            const _listingCap = 2 ** 16 - 1
            const assetGovernance = await AssetGovernance.deploy(
                governance.address,
                token.address, _listingFee, _listingCap, governor,
                30, 0, 5
            )
            await assetGovernance.deployed()
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
            const addControllerTx = await znsController.addController(zecreyLegend.address);
            await addControllerTx.wait();

            const isController = await znsController.controllers(zecreyLegend.address)
            console.log(isController)

            // deploy additional zecrey legend
            const AdditionalZecreyLegend = await ethers.getContractFactory('AdditionalZecreyLegend')
            const additionalZecreyLegend = await AdditionalZecreyLegend.deploy()
            await additionalZecreyLegend.deployed()

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

            const registerZNSTx = await zecreyLegend.registerZNS('sher',
                '0xDA00601380Bc7aE4fe67dA2EB78f9161570c9EB4',
                '0x6788fdbc635cf86e266853a628b2743643df5c1db1a4f9afbb13bca103322e9a')
            await registerZNSTx.wait()

            const hashVal = namehash.hash('sher.legend');
            const addr = await zecreyLegend.getAddressByAccountNameHash(hashVal)
            console.log('addr:', addr)
        });
    });
});

const getKeccak256 = (name) => {
    return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name))
}