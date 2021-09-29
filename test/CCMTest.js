const { ethers } = require("hardhat");
const hre = require("hardhat");
const fs = require("fs");
const crypto = require("crypto");
const Web3 = require("web3");
const { expect } = require("chai");
const bytes = require("@ethersproject/bytes");
hre.web3 = new Web3(hre.network.provider);

describe("CCMtest", async function () {

  let empty32 = '0x0000000000000000000000000000000000000000000000000000000000000000';
  let empty20 = '0x0000000000000000000000000000000000000000';
  let deployer;
  let addr1;
  let addr2;
  let eccd;
  let factory;
  let ccmi;
  let ccmp;
  let ccm;
  let caller;
  let calleri;
  let callerp;

  describe("initialize", function () {
    it("Should do deployment ",async function () {
      [deployer,addr1,addr2] = await hre.ethers.getSigners();

      await hre.run('compile');
      
      // deploy EthCrossChainData
      const ECCD = await hre.ethers.getContractFactory("EthCrossChainData");
      eccd = await ECCD.deploy();
      await eccd.deployed();
      
      // deploy CallerFactory
      const CallerFactory = await hre.ethers.getContractFactory("CallerFactory");
      factory = await CallerFactory.deploy();
      await factory.deployed();
      
      // update Const.sol
      await updateConst(eccd.address, factory.address);
      await hre.run('compile');
      
      // deploy EthCrossChainManagerImplemetation
      const CCM = await hre.ethers.getContractFactory("EthCrossChainManagerImplemetation");
      ccmi = await CCM.deploy();
      await ccmi.deployed();
        
      // deploy EthCrossChainManager
      const CCMP = await hre.ethers.getContractFactory("EthCrossChainManager");
      ccmp = await CCMP.deploy(ccmi.address,deployer.address,'0x');
      await ccmp.deployed();

      ccm = await CCM.attach(ccmp.address);
    });

    it("Should transfer eccd's owner", async function () {
      expect(await eccd.owner()).to.equal(deployer.address);
      await eccd.transferOwnership(ccm.address);
      expect(await eccd.owner()).to.equal(ccm.address);
    });
  });

  describe("ProxyFactory", function () {

    it("Should deploy caller implemetaion & caller", async function () {
      // deploy caller implementation
      const Caller = await hre.ethers.getContractFactory("EthCrossChainCaller");
      const CallerMock = await hre.ethers.getContractFactory("CallerImplemetationMock");
      calleri = await CallerMock.deploy();
      await calleri.deployed();
      
      let salt = 77777;
      let preCalcAddress = await factory.getDeploymentAddress(salt, addr1.address);
      expect(await factory.isChild(preCalcAddress)).to.equal(false);
      // deploy caller ,  initialize(address).selector = 0xc4d66de8
      await factory.connect(addr1).deploy(salt, calleri.address, addr1.address, '0xc4d66de8000000000000000000000000'+ccm.address.slice(2));

      expect(await factory.isChild(preCalcAddress)).to.equal(true);
      expect(await factory.isChild(calleri.address)).to.equal(false);

      caller = await CallerMock.attach(preCalcAddress);
      callerp = await Caller.attach(preCalcAddress);

      expect(await caller.connect(addr2).whoAmI()).to.equal(1);
    });

    it("Should deploy caller via signature", async function () {
      const CallerSigMsgGen = await hre.ethers.getContractFactory("CallerSigMsgGen");
      let smg = await CallerSigMsgGen.deploy();
      let salt = 66666;
      let logic = calleri.address;
      let admin = addr2.address;
      let data = '0xc4d66de8000000000000000000000000'+ccm.address.slice(2);
      let signer = addr2;
      let msg = await smg.getSigMsg(salt, logic, admin, data, factory.address);
      let sig = await signer.signMessage(bytes.arrayify(msg));
      let preCalcAddress = await factory.getDeploymentAddress(salt, signer.address);
      expect(await factory.isChild(preCalcAddress)).to.equal(false);
      await factory.connect(addr1).deploySigned(salt, logic, admin, data, sig);
      expect(await factory.isChild(preCalcAddress)).to.equal(true);
    });

    it("Should not get correct caller while deploy via fake signature", async function () {
      const CallerSigMsgGen = await hre.ethers.getContractFactory("CallerSigMsgGen");
      let smg = await CallerSigMsgGen.deploy();
      let salt_fake = 1234;
      let salt = 1111;
      let logic = calleri.address;
      let admin = addr2.address;
      let data = '0xc4d66de8000000000000000000000000'+ccm.address.slice(2);
      let signer = addr2;
      let msg = await smg.getSigMsg(salt_fake, logic, admin, data, factory.address);
      let sig = await signer.signMessage(msg);
      let preCalcAddress = await factory.getDeploymentAddress(salt, signer.address);
      expect(await factory.isChild(preCalcAddress)).to.equal(false);
      await factory.connect(addr1).deploySigned(salt, logic, admin, data, sig);
      expect(await factory.isChild(preCalcAddress)).to.equal(false);
    });

    it("Should fail if not admin try to set implementation", async function () {
      await expect(callerp.connect(addr2).upgradeTo(ccmi.address)).to.be.reverted;
    });

    it("Should success if admin try to set implementation", async function () {
      const CallerMock2 = await hre.ethers.getContractFactory("CallerImplemetationMock_2");
      calleri2 = await CallerMock2.deploy();
      await calleri2.deployed();
      await callerp.connect(addr1).upgradeTo(calleri2.address);
      expect(await caller.connect(addr2).whoAmI()).to.equal(2);
      await callerp.connect(addr1).upgradeTo(calleri.address);
      expect(await caller.connect(addr2).whoAmI()).to.equal(1);
    });

    it("Should fail if not admin try to change admin", async function () {
      await expect(callerp.connect(addr2).changeAdmin(addr2.address)).to.be.reverted;
    });

    it("Should success if admin try to change admin", async function () {
      await callerp.connect(addr1).changeAdmin(addr2.address);
      await expect(callerp.connect(addr1).changeAdmin(addr1.address)).to.be.reverted;
      await callerp.connect(addr2).changeAdmin(addr1.address);
    });
  });

  describe("EthCrossChainManager", function () {
    
    // upgradeTo
    it("Should fail if not admin try to set implementation", async function () {
      const CCMMock = await hre.ethers.getContractFactory("CCMMock");
      let mock = await CCMMock.deploy();
      await expect(ccmp.connect(addr2).upgradeTo(mock.address)).to.be.reverted;
    });

    it("Should success if admin try to set implementation", async function () {
      const CCMMock = await hre.ethers.getContractFactory("CCMMock");
      let mock = await CCMMock.deploy();
      let mockccm = await CCMMock.attach(ccm.address);
      await ccmp.connect(deployer).upgradeTo(mock.address);
      expect(await mockccm.connect(addr2).iAmMock()).to.equal(true);
      await ccmp.connect(deployer).upgradeTo(ccmi.address);
      await expect( mockccm.connect(addr2).iAmMock()).to.be.reverted;
    });
    
    // changeAdmin
    it("Should fail if not admin try to change admin", async function () {
      await expect(ccmp.connect(addr2).changeAdmin(addr2.address)).to.be.reverted;
    });

    it("Should success if admin try to change admin", async function () {
      await ccmp.connect(deployer).changeAdmin(addr2.address);
      await expect(ccmp.connect(deployer).changeAdmin(deployer.address)).to.be.reverted;
      await ccmp.connect(addr2).changeAdmin(deployer.address);
    });

    // crossChain
    it("Should success when try to call crossChain from valid caller (child of factory) ", async function () {
      let args = "0x123456"
      let index = await eccd.getEthTxHashIndex();
      expect(await eccd.getEthTxHash(index)).to.equal(empty32);
      await expect(caller.lock(args)).to.not.reverted;
      expect(await eccd.getEthTxHash(index)).to.not.equal(empty32);
      expect(await eccd.getEthTxHashIndex()).to.equal(index+1);
    });
    
    it("Should fail when try to call crossChain from invalid caller (not child of factory) ", async function () {
      let args = "0x123456"
      await calleri.initialize(ccm.address);
      await expect(calleri.lock(args)).to.be.reverted;
    });
    
    // TODO
    // initGenesisBlock
    it("Should success when try to call initGenesisBlock at uninitialized CCM ", async function () {
    });
    
    // TODO
    it("Should fail when try to call initGenesisBlock at already initialized CCM ", async function () {
    });

    // TODO
    // changeEpoch
    it("Should success when try to call changeEpoch with correct header & seals & proof & epochInfo ", async function () {
    });
    
    // TODO
    it("Should fail when try to call changeEpoch with incorrect header ", async function () {
    });
    
    // TODO
    it("Should fail when try to call changeEpoch with incorrect seals ", async function () {
    });
    
    // TODO
    it("Should fail when try to call changeEpoch with incorrect proof ", async function () {
    });
    
    // TODO
    it("Should fail when try to call changeEpoch with incorrect epochInfo ", async function () {
    });

    // TODO
    // verifyHeaderAndExecuteTx
    it("Should success when try to call verifyHeaderAndExecuteTx with correct header & seals & proof & crossTx ", async function () {
    });
    
    // TODO
    it("Should fail when try to call verifyHeaderAndExecuteTx with incorrect header ", async function () {
    });
    
    // TODO
    it("Should fail when try to call verifyHeaderAndExecuteTx with incorrect seals ", async function () {
    });
    
    // TODO
    it("Should fail when try to call verifyHeaderAndExecuteTx with incorrect proof ", async function () {
    });
    
    // TODO
    it("Should fail when try to call verifyHeaderAndExecuteTx with incorrect crossTx ", async function () {
    });


  });
});


async function updateConst(eccd, callerFactory) {
  // const polyChainId = await getPolyChainId();
  polyChainId = 2;

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
        return console.error(err);
    }
  }); 
}

