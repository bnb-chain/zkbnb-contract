const hardhat = require('hardhat');
const { getDeployedAddresses, getZkBNBProxy } = require('./utils');
const { ethers } = hardhat;

async function main() {
  const network = hardhat.network.name;
  isLocal = false;
  if (network === 'local' || network == 'hardhat') {
    isLocal = true;
  }

  const addrs = getDeployedAddresses('info/addresses.json');
  const zkbnb = await getZkBNBProxy(addrs.zkbnbProxy);

  const [owner] = await ethers.getSigners();

  const validators = (process.env.VALIDATORS || owner.address).split(',');
  const treasuryAccountAddress = process.env.TREASURY_ACCOUNT_ADDRESS || validators[0] || owner.address;
  const gasAccountAddress = process.env.GAS_ACCOUNT_ADDRESS || validators[1] || owner.address;

  // tokens
  const TokenFactory = await ethers.getContractFactory('ZkBNBRelatedERC20');
  const BUSDToken = TokenFactory.attach(addrs.BUSDToken);

  // deposit bnb
  console.log('Deposit BNB...');
  let depositBNBTx = await zkbnb.depositBNB(treasuryAccountAddress, {
    value: ethers.utils.parseEther('0.01'),
  });
  await depositBNBTx.wait();
  depositBNBTx = await zkbnb.depositBNB(gasAccountAddress, {
    value: ethers.utils.parseEther('0.01'),
  });
  await depositBNBTx.wait();

  // set allowance
  console.log('Set allowance...');

  const setAllowanceTx = await BUSDToken.approve(zkbnb.address, ethers.utils.parseEther('100000000000'));
  await setAllowanceTx.wait();

  // deposit bep20
  console.log('Deposit BEP20...');
  let depositBEP20Tx;
  const AssetGovernance =  await ethers.getContractFactory('AssetGovernance');
  const assetGovernance = AssetGovernance.attach(addrs.assetGovernance);
  
  if (isLocal) {
    const LEGToken = await TokenFactory.deploy(ethers.utils.parseEther('100000000000'), 'LEGToken', 'LEG');
    await LEGToken.deployed();

    const addAssetTx = await assetGovernance.addAsset(LEGToken.address);
    await addAssetTx.wait();

    const setBEP20AllowanceTx = await LEGToken.approve(zkbnb.address, ethers.utils.parseEther('100000000000'));
    await setBEP20AllowanceTx.wait()

    depositBEP20Tx = await zkbnb.depositBEP20(LEGToken.address, ethers.utils.parseEther('100'), treasuryAccountAddress);
  } else {
    depositBEP20Tx = await zkbnb.depositBEP20(
      BUSDToken.address,
      ethers.utils.parseEther('100'),
      treasuryAccountAddress,
    );
  }
  await depositBEP20Tx.wait();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err.message || err);
    process.exit(1);
  });
