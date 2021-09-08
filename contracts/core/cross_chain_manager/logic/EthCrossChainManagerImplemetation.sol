pragma solidity ^0.5.0;

import "../interface/IEthCrossChainData.sol";
import "../data/EthCrossChainData.sol";
import "../caller/CallerFactory.sol";
import "../caller/EthCrossChainCaller.sol"; 
import "../caller/EthCrossChainCaller.sol"; 
import "../libs/ECCUtils/EthCrossChainUtils.sol";
import "./../../../libs/math/SafeMath.sol";
import "./../../../libs/utils/Utils.sol";

contract EthCrossChainManager {
    using SafeMath for uint256;

    event InitGenesisBlockEvent(uint256 height, bytes rawHeader);
    event ChangeEpochEvent(uint256 height, bytes rawHeader, bytes oldValidatorSet, bytes newEpochInfo);
    event CrossChainEvent(address indexed sender, bytes txId, address proxyOrAssetContract, uint64 toChainId, bytes toContract, bytes rawdata);
    event VerifyHeaderAndExecuteTxEvent(uint64 fromChainID, bytes toContract, bytes crossChainTxHash, bytes fromChainTxHash);

    address constant EthCrossChainDataAddress = 0x0000000000000000000000000000000000000000;
    address constant EthCrossChainCallerFactoryAddress = 0x0000000000000000000000000000000000000000;

    bytes constant ZionCrossChainManagerAddress = "0x000000000000000000000000000000000000000000";

    bytes constant ZionValidaterManagerAddress = "0x000000000000000000000000000000000000000000";
    bytes constant CurrentValidatorSetSlot = "0x000000000000000000000000000000000000000000";
    bytes constant NextValidatorSetSlot = "0x000000000000000000000000000000000000000000";

    uint constant chainId = 0;
    
    function initGenesisBlock(
        bytes memory rawHeader, 
        bytes memory rawSeals,
        bytes memory accountProof, 
        bytes memory storageProof,
        bytes memory currentEpochInfo
    ) public returns(bool) {
        ECCUtils.Header memory header = ECCUtils.decodeHeader(rawHeader);
        ECCUtils.EpochInfo memory curEpoch = ECCUtils.decodeEpochInfo(currentEpochInfo);
        IEthCrossChainData eccd = IEthCrossChainData(EthCrossChainDataAddress);

        require(eccd.getCurEpochValidatorPkBytes().length == 0, "EthCrossChainData contract has already been initialized!");
        require(header.number>=curEpoch.epochStartHeight && header.number<curEpoch.epochEndHeight, "Invalid block height");
        require(ECCUtils.verifyHeader(keccak256(rawHeader), rawSeals, curEpoch.validators), "Verify header failed");
        bytes memory storageValue = ECCUtils.verifyAccountProof(accountProof, header.root, ZionValidaterManagerAddress, storageProof, CurrentValidatorSetSlot);
        require(Utils.bytesToBytes32(storageValue) == keccak256(currentEpochInfo), "Verify proof failed");
        
        require(eccd.putCurEpochHeight(curEpoch.epochStartHeight, curEpoch.epochEndHeight), "Save Zion current epoch start & end height to Data contract failed!");
        require(eccd.putCurEpochValidatorPkBytes(ECCUtils.encodeValidators(curEpoch.validators)), "Save Zion current epoch validators to Data contract failed!");
        
        emit InitGenesisBlockEvent(header.number, rawHeader);
        return true;
    }
    
    function changeEpoch(
        bytes memory rawHeader, 
        bytes memory rawSeals,
        bytes memory accountProof, 
        bytes memory storageProof,
        bytes memory nextEpochInfo
    ) public returns(bool) {
        ECCUtils.Header memory header = ECCUtils.decodeHeader(rawHeader);
        ECCUtils.EpochInfo memory nextEpoch = ECCUtils.decodeEpochInfo(nextEpochInfo);
        IEthCrossChainData eccd = IEthCrossChainData(EthCrossChainDataAddress);
        
        (,uint256 curEpochEndHeight) = eccd.getCurEpochHeight();
        require(header.number==curEpochEndHeight, "Given block height is not epoch end height");
        
        bytes memory curPkBytes = eccd.getCurEpochValidatorPkBytes();
        address[] memory validators = ECCUtils.decodeValidators(curPkBytes);
        require(ECCUtils.verifyHeader(keccak256(rawHeader), rawSeals, validators), "Verify header failed");
        
        bytes memory storageValue = ECCUtils.verifyAccountProof(accountProof, header.root, ZionValidaterManagerAddress, storageProof, NextValidatorSetSlot);
        require(Utils.bytesToBytes32(storageValue) == keccak256(nextEpochInfo), "Verify proof failed");

        require(eccd.putCurEpochHeight(nextEpoch.epochStartHeight, nextEpoch.epochEndHeight), "Save next epoch height to Data contract failed!");
        require(eccd.putCurEpochValidatorPkBytes(ECCUtils.encodeValidators(nextEpoch.validators)), "Save Zion next epoch validators to Data contract failed!");
        
        emit ChangeEpochEvent(header.number, rawHeader, curPkBytes, nextEpochInfo);
        return true;
    }
   
    function crossChain(
        uint64 toChainId, 
        bytes calldata toContract, 
        bytes calldata method, 
        bytes calldata txData
    ) external returns (bool) {
        
        uint256 txHashIndex = IEthCrossChainData(EthCrossChainDataAddress).getEthTxHashIndex();
        bytes memory paramTxHash = Utils.uint256ToBytes(txHashIndex);
        bytes memory crossChainId = abi.encodePacked(sha256(abi.encodePacked(address(this), paramTxHash)));
        bytes memory rawParam = 
        ECCUtils.encodeTxParam(
            paramTxHash,
            crossChainId,
            Utils.addressToBytes(msg.sender),
            toChainId,
            toContract,
            method,
            txData
        );
        
        require(IEthCrossChainData(EthCrossChainDataAddress).putEthTxHash(keccak256(rawParam)), "Save ethTxHash by index to Data contract failed!");
        
        emit CrossChainEvent(tx.origin, paramTxHash, msg.sender, toChainId, toContract, rawParam);
        return true;
    }

    function verifyHeaderAndExecuteTx(
        bytes memory rawHeader,
        bytes memory rawSeals,
        bytes memory accountProof, 
        bytes memory storageProof,
        bytes memory rawCrossTx
    ) public returns (bool)
    {
        ECCUtils.Header memory header = ECCUtils.decodeHeader(rawHeader);
        ECCUtils.CrossTx memory crossTx = ECCUtils.decodeCrossTx(rawCrossTx);
        IEthCrossChainData eccd = IEthCrossChainData(EthCrossChainDataAddress);
        
        address[] memory validators = ECCUtils.decodeValidators(eccd.getCurEpochValidatorPkBytes());
        (uint256 curEpochStartHeight , uint256 curEpochEndHeight) = eccd.getCurEpochHeight();

        require(header.number>=curEpochStartHeight && header.number<curEpochEndHeight, "Invalid block height");
        require(ECCUtils.verifyHeader(keccak256(rawHeader), rawSeals, validators), "Verify header failed");
        bytes memory storageIndex = ECCUtils.getStorageSlot(crossTx);
        bytes memory storageValue = ECCUtils.verifyAccountProof(accountProof, header.root, ZionCrossChainManagerAddress, storageProof, storageIndex);
        require(Utils.bytesToBytes32(storageValue) == keccak256(rawCrossTx), "Verify proof failed");

        require(!eccd.checkIfFromChainTxExist(crossTx.fromChainID, Utils.bytesToBytes32(crossTx.txHash)), "the transaction has been executed!");
        require(eccd.markFromChainTxExist(crossTx.fromChainID, Utils.bytesToBytes32(crossTx.txHash)), "Save crosschain tx exist failed!");
        require(crossTx.crossTxParam.toChainId == chainId, "This Tx is not aiming at this network!");

        address toContract = Utils.bytesToAddress(crossTx.crossTxParam.toContract);
        
        require(_executeCrossChainTx(toContract, crossTx.crossTxParam.method, crossTx.crossTxParam.args, crossTx.crossTxParam.fromContract, crossTx.fromChainID), "Execute CrossChain Tx failed!");

        emit VerifyHeaderAndExecuteTxEvent(crossTx.fromChainID, crossTx.crossTxParam.toContract, crossTx.txHash, crossTx.crossTxParam.txHash);

        return true;
    }

    function _executeCrossChainTx(
        address _toContract, bytes memory _method, bytes memory _args, bytes memory _fromContractAddr, uint64 _fromChainId
    ) internal returns (bool)
    {
        require(CallerFactory(EthCrossChainCallerFactoryAddress).isChild(_toContract), "The passed in address is not from the factory!");
        require(_toContract!=EthCrossChainDataAddress, "Don't try to call eccd!");
        
        (bool success, bytes memory returnData) = _toContract.call(abi.encodePacked(bytes4(keccak256(abi.encodePacked(_method, "(bytes,bytes,uint64)"))), abi.encode(_args, _fromContractAddr, _fromChainId)));
        
        require(success == true, "EthCrossChain call business contract failed");
        
        require(returnData.length != 0, "No return value from business contract!");
        bool res = abi.decode(returnData, (bool));
        require(res == true, "EthCrossChain call business contract return is not true");
        
        return true;
    }  
}