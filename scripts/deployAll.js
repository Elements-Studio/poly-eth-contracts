const hre = require("hardhat");
const Web3 = require("web3");
const fs = require("fs");
hre.web3 = new Web3(hre.network.provider);
require("colors");

async function main() {
    [deployer, deployer2] = await hre.ethers.getSigners();
  
    // check if given networkId is registered
    await getPolyChainId().then((polyId) => {
      console.log("\nDeploy contracts on chain with Poly_Chain_Id:".cyan, polyId);
    }).catch((error) => {
      throw error;
    });

    console.log("\nStart , deployer:".cyan, deployer.address.blue);
  
    // deploy EthCrossChainData
    console.log("\ndeploy EthCrossChainData ......".cyan);
    const ECCD = await hre.ethers.getContractFactory("EthCrossChainData");
    const eccd = await ECCD.deploy();
    await eccd.deployed();
    console.log("EthCrossChainData deployed to:".green, eccd.address.blue);
    
    // deploy CallerFactory
    console.log("\ndeploy CallerFactory ......".cyan);
    const CallerFactory = await hre.ethers.getContractFactory("CallerFactory");
    const cf = await CallerFactory.deploy();
    await cf.deployed();
    console.log("CallerFactory deployed to:".green, cf.address.blue);
    
    // update Const.sol
    console.log("\nupdate Const.sol ......".cyan);
    await updateConst(eccd.address, cf.address);
    console.log("Const.sol updated".green);
    await hre.run('compile');
    
    // deploy EthCrossChainManagerImplementation
    console.log("\ndeploy EthCrossChainManagerImplementation ......".cyan);
    const CCM = await hre.ethers.getContractFactory("EthCrossChainManagerImplementation");
    const ccm = await CCM.deploy();
    await ccm.deployed();
    console.log("EthCrossChainManagerImplementation deployed to:".green, ccm.address.blue);
    
    // deploy EthCrossChainManager
    console.log("\ndeploy EthCrossChainManager ......".cyan);
    const CCMP = await hre.ethers.getContractFactory("EthCrossChainManager");
    const ccmp = await CCMP.deploy(ccm.address,deployer.address,'0x');
    await ccmp.deployed();
    console.log("EthCrossChainManager deployed to:".green, ccmp.address.blue);
  
    // transfer ownership
    console.log("\ntransfer eccd's ownership to ccm ......".cyan);
    await eccd.transferOwnership(ccmp.address);
    console.log("ownership transferred".green);
    
    // deploy LockProxy
    console.log("\ndeploy LockProxy ......".cyan);
    const LockProxy = await ethers.getContractFactory("LockProxy");
    const lockProxy = await LockProxy.deploy();
    await lockProxy.deployed();
    console.log("LockProxy deployed to:".green, lockProxy.address.blue);

    // deploy EthCrossChainManagerImplementation
    console.log("\ndeploy TunnelCCMCallerImplementation ......".cyan);
    const TunnelCCMCaller = await ethers.getContractFactory("TunnelCCMCaller");
    const tunnelCalleri = await TunnelCCMCaller.deploy();
    await tunnelCalleri.deployed();
    console.log("TunnelCCMCallerImplementation deployed to:".green, tunnelCalleri.address.blue);
    
    // deploy TunnelCCMCaller
    console.log("\ndeploy TunnelCCMCaller ......".cyan);
    let salt = 777;
    let tunnelCallerAddress = await cf.getDeploymentAddress(salt, deployer2.address);
    await cf.connect(deployer2).deploy(salt, tunnelCalleri.address, deployer2.address, '0xc4d66de8000000000000000000000000'+deployer.address.slice(2));
    tunnelCaller = await TunnelCCMCaller.attach(tunnelCallerAddress);
    console.log("TunnelCCMCaller deployed to:".green, tunnelCaller.address.blue);

    // setup contracts
    console.log("\nsetup TunnelCCMCaller && LockProxy ......".cyan);
    await tunnelCaller.setRealCCM(ccm.address);
    console.log("TunnelCCMCaller set".green);
    await lockProxy.setManagerProxy(tunnelCaller.address);
    console.log("LockProxy set".green);

    console.log("\nDone.\n".magenta);
}

async function updateConst(eccd, callerFactory) {
    const polyChainId = await getPolyChainId();
  
    await fs.writeFile('./contracts/core/cross_chain_manager/logic/Const.sol', 
    'pragma solidity ^0.5.0;\n'+
    'contract Const {\n'+
    '    bytes constant ZionCrossChainManagerAddress = hex"5747C05FF236F8d18BB21Bc02ecc389deF853cae"; \n'+
    '    bytes constant ZionValidaterManagerAddress = hex"A4Bf827047a08510722B2d62e668a72FCCFa232C"; \n'+
    '    address constant EthCrossChainDataAddress = '+eccd+'; \n'+
    '    address constant EthCrossChainCallerFactoryAddress = '+callerFactory+'; \n'+
    '    uint constant chainId = '+polyChainId+'; \n}', 
    function(err) {
      if (err) {
          console.error(err);
          process.exit(1);
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
    case 421611: // arbitrum-test
      return 205;
    case 77: // xdai-test
      return 206;
    case 69: // op-test
      return 207;

    // hardhat devnet
    case 31337:
      return 77777;

    // unknown chainid
    default: 
      throw new Error("fail to get Poly_Chain_Id, unknown Network_Id: "+chainId);
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
      console.error(err)
      process.exit(1)
  });
