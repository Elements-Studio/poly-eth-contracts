const { ethers } = require("hardhat");
const hre = require("hardhat");
const fs = require("fs");
const Web3 = require("web3");
const { expect } = require("chai");
hre.web3 = new Web3(hre.network.provider);

describe("ECCUtils", function () {

    let ECCUtilsMock;
    let eccu;
    let addr1;
    let addr2;
    let addrs;

    beforeEach(async function () {
        ECCUtilsMock = await ethers.getContractFactory("ECCUtilsMock");
        [addr1, addr2, ...addrs] = await ethers.getSigners();

        eccu = await ECCUtilsMock.deploy();
    });

    describe("verifyAccountProof", function () {

        let accountProof = 0x12;
        let headerRoot = 0x12;
        let address = 0x12;
        let storageProof = 0x12;
        let storageIndex = 0x12;

        it("Should return storage value", async function () {
        });
    });

    describe("verifyProof", function () {

        let proof = 0x12;
        let rootValid = 0x12;
        let keyValid = 0x12;
        let rootInvalid = 0x23;
        let keyInvalid = 0x45;

        it("Should return value while ok", async function () {
        });

        it("Should revert if key is invalid", async function () {
        });

        it("Should revert if root is invalid", async function () {
        });

    });

    describe("verifyHeader", function () {
        let headerHash = 0x1234;
        let validators = [];
        let rawSealsValid1 = 0x1234;
        let rawSealsValid2 = 0x1234;
        let rawSealsInvalid1 = 0x1234;
        let rawSealsInvalid2 = 0x1234;

        it("Should return true while there is enough valid seals", async function () {
        });

        it("Should return false while there is no enough valid seals", async function () {
        });

        it("Should return true while there is fake seals and enough valid seals", async function () {
        });

        it("Should return false while there is fake seals and no enough valid seals", async function () {
        });

    });

    describe("verifySeal", function () {
        let headerHash = 0x1234;
        let validator = 0x1234;
        let sealValid = 0x1234;
        let sealInvalid = 0x1234;

        it("Should return signer while seal is valid", async function () {
        });

        it("Should return address(0) while seal is invalid", async function () {
        });

    });

    describe("hasEnoughSigners", function () {
        let validators = [];
        let signersValid = [];
        let signersInvalid1 = [];
        let signersInvalid2 = [];

        it("Should return true while there is enough signers", async function () {
        });

        it("Should return false while there is no enough signers", async function () {
        });

        it("Should return false while there exists address(0) and no enough signers", async function () {
        });

    });

    describe("decodeHeader", function () {
        let rawHeader = 0x1234;
        let root = 0x1234;
        let number = 0x1234;

        it("Should return block.root and block.number", async function () {
        });

    });

    describe("getStorageSlot", function () {
        let zionTxHash = 0x1234;
        let toChainId = 0x1234;
        let slotIndex = 0x1234;

        it("Should return correct slot index", async function () {
        });

    });

    describe("getStorageSlot", function () {
        let zionTxHash = 0x1234;
        let toChainId = 0x1234;
        let slotIndex = 0x1234;

        it("Should return correct slot index", async function () {
        });

    });

    describe("type conversion", function () {
        let _address = 0x1234;
        let _bytes32 = 0x1234;
        let _uint256 = 34;
        let _uint64 = 12;

        it("bytes32ToBytes", async function () {
        });

        it("uint256ToBytes", async function () {
        });

        it("addressToBytes", async function () {
        });

        it("bytesToBytes32", async function () {
        });

        it("bytesToUint256", async function () {
        });

        it("bytesToAddress", async function () {
        });

    });

    describe("encode & decode", function () {
        // validators
        let rawValidatorBytes = 0x1234;
        let validators = [];

        // EpochInfo
        let rawEpochInfo = 0x34;
        let epochStartHeight = 1;
        let epochEndHeight = 2;
        
        // CrossTx
        let rawCrossTx = 0x12;
        let ziontxHash = 0x12;
        let fromChainID = 0x12;

        // TxParam
        let rawTxParam = 0x12;
        let sourceTxHash = 0x12;
        let crossChainId = 0x12;
        let fromContract = 0x12;
        let toChainId = 0x12;
        let toContract = 0x12;
        let method = 0x12;
        let arg = 0x12;


        it("decodeValidators", async function () {
        });

        it("encodeValidators", async function () {
        });

        it("decodeEpochInfo", async function () {
        });

        it("encodeTxParam", async function () {
        });

        it("decodeTxParam", async function () {
        });

        it("decodeCrossTx", async function () {
        });

    });

    describe("rlp decode", function () {

        it("rlpGetNextBytes", async function () {
        });

        it("rlpGetNextBytes32", async function () {
        });

        it("rlpGetNextUint64", async function () {
        });

        it("rlpGetNextUint256", async function () {
        });

        it("rlpSplit", async function () {
        });

        it("rlpReadKind", async function () {
        });

    });

    describe("key conversion", function () {

        it("bytesToHex", async function () {
        });

        it("compactToHex", async function () {
        });

        it("hexToCompact", async function () {
        });

    });

    describe("checkNodeHash", function () {

        it("Should return true while ok", async function () {
        });

        it("Should return false while not ok", async function () {
        });

    });

    describe("takeOneByte", function () {

        it("Should take one byte", async function () {
        });

    });

    describe("compareKey", function () {

        it("Should return true while ok", async function () {
        });

        it("Should return false if key element unmatch", async function () {
        });

    });

});
