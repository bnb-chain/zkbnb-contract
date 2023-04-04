const fs = require('fs');
const { ethers } = require('hardhat');
const poseidonContract = require('../../test/desertMode/poseidon_gencontract');

// Read deployed addresses from file
exports.getDeployedAddresses = function (path) {
  const raw = fs.readFileSync(path);
  return JSON.parse(raw);
};

// Write deployed addresses to json file
exports.saveDeployedAddresses = function (path, addrs) {
  const data = JSON.stringify(addrs, null, 2);
  fs.writeFileSync(path, data);
};

exports.saveConstructorArgumentsForVerify = function (path, args) {
  const data = JSON.stringify(args, null, 2);
  fs.writeFileSync(path, data);
};

exports.getZkBNBProxy = async function (addr) {
  // Get utils contract
  const Utils = await ethers.getContractFactory('Utils');
  const utils = await Utils.deploy();
  await utils.deployed();

  // zkbnb
  const ZkBNB = await ethers.getContractFactory('ZkBNB', {
    libraries: {
      Utils: utils.address,
    },
  });

  return ZkBNB.attach(addr);
};

// Get the keccak256 hash of a specified string name
// eg: getKeccak256('zkbnb') = '0x621eacce7c1f02dbf62859801a97d1b2903abc1c3e00e28acfb32cdac01ab36d'
exports.getKeccak256 = function (name) {
  return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name));
};

exports.deployDesertVerifier = async function (owner) {
  const PoseidonT3 = new ethers.ContractFactory(poseidonContract.generateABI(2), poseidonContract.createCode(2), owner);
  const poseidonT3 = await PoseidonT3.deploy();
  await poseidonT3.deployed();

  const PoseidonT6 = new ethers.ContractFactory(poseidonContract.generateABI(5), poseidonContract.createCode(5), owner);
  const poseidonT6 = await PoseidonT6.deploy();
  await poseidonT6.deployed();

  const PoseidonT7 = new ethers.ContractFactory(poseidonContract.generateABI(6), poseidonContract.createCode(6), owner);
  const poseidonT7 = await PoseidonT7.deploy();
  await poseidonT7.deployed();

  const DesertVerifier = await ethers.getContractFactory('DesertVerifier');
  const desertVerifier = await DesertVerifier.deploy(poseidonT3.address, poseidonT6.address, poseidonT7.address);
  await desertVerifier.deployed();

  return desertVerifier;
};
