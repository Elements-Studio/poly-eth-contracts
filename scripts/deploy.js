const { ethers } = require("hardhat");
const hre = require("hardhat");
const fs = require("fs");
const Web3 = require("web3");
hre.web3 = new Web3(hre.network.provider);

async function main() {

  [deployer] = await hre.ethers.getSigners();

  console.log("Start , deployer:", deployer.address);

  await hre.run('compile');
  
  // deploy EthCrossChainData
  console.log("\ndeploy EthCrossChainData ......");
  const ECCD = await hre.ethers.getContractFactory("EthCrossChainData");
  const eccd = await ECCD.deploy();
  await eccd.deployed();
  console.log("EthCrossChainData deployed to:", eccd.address);
  
  // deploy CallerFactory
  console.log("\ndeploy CallerFactory ......");
  const CallerFactory = await hre.ethers.getContractFactory("CallerFactory");
  const cf = await CallerFactory.deploy();
  await cf.deployed();
  console.log("CallerFactory deployed to:", cf.address);
  
  // update Const.sol
  console.log("\nupdate Const.sol ......");
  await updateConst(eccd.address, cf.address);
  console.log("Const.sol updated");
  await hre.run('compile');
  
  // deploy EthCrossChainManagerImplemetation
  console.log("\ndeploy EthCrossChainManagerImplemetation ......");
  const CCM = await hre.ethers.getContractFactory("EthCrossChainManagerImplemetation");
  const ccm = await CCM.deploy();
  await ccm.deployed();
  console.log("EthCrossChainManagerImplemetation deployed to:", ccm.address);
  
  // deploy EthCrossChainManager
  console.log("\ndeploy EthCrossChainManager ......");
  const CCMP = await hre.ethers.getContractFactory("EthCrossChainManager");
  const ccmp = await CCMP.deploy(ccm.address,deployer.address,'0x');
  await ccmp.deployed();
  console.log("EthCrossChainManager deployed to:", ccmp.address);

  // transfer ownership
  console.log("\ntransfer eccd's ownership to ccm ......");
  await eccd.transferOwnership(ccmp.address);
  console.log("ownership transferred");

  console.log("\nDone");

}

async function updateConst(eccd, callerFactory) {
  const polyChainId = await getPolyChainId();

  await fs.writeFile('./contracts/core/cross_chain_manager/logic/Const.sol', 
  'pragma solidity ^0.5.0;\n'+
  'contract Const {\n'+
  '    bytes constant ZionCrossChainManagerAddress = hex"5747C05FF236F8d18BB21Bc02ecc389deF853cae"; \n'+
  '    bytes constant ZionValidaterManagerAddress = hex"A4Bf827047a08510722B2d62e668a72FCCFa232C"; \n'+
  '    bytes constant CurrentValidatorSetSlot = hex"1111"; \n'+
  '    bytes constant NextValidatorSetSlot = hex"1111"; \n'+
  '    address constant EthCrossChainDataAddress = '+eccd+'; \n'+
  '    address constant EthCrossChainCallerFactoryAddress = '+callerFactory+'; \n'+
  '    uint constant chainId = '+polyChainId+'; \n}', 
  function(err) {
    if (err) {
        return console.error(err);
    }
  }); 
}

async function getPolyChainId() {
  const chainId = await hre.web3.eth.getChainId();
  switch (chainId) {
    
    // mainnet
    case 1: // eth-main
      return 2;
    case 56: // bsc-main
      return 6;
    case 128: // heco-main
      return 7;
    case 137: // polygon-main
      return 17;
    case 66: // ok-main
      return 12;
    case 1718: // plt-main
      return 8;

    // testnet
    case 3: // eth-test
      return 2;
    case 97: // bsc-test
      return 79;
    case 256: // heco-test
      return 7;
    case 80001: // polygon-test
      return 202;
    case 65: // ok-test
      return 200;
    case 101: // plt-test
      return 107;

    // default/dev
    default: 
      return 7777;
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

