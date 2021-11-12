pragma solidity ^0.5.0;
import "./../../../libs/common/ZeroCopySource.sol";
import "./../../../libs/common/ZeroCopySink.sol";
import "./../../../libs/utils/Utils.sol";
import "./../../../libs/math/SafeMath.sol";

import "hardhat/console.sol";

library ECCUtils {
    using SafeMath for uint256;
    
    struct Header {
        uint32 version;
        uint64 chainId;
        uint32 timestamp;
        uint32 height;
        uint64 consensusData;
        bytes32 prevBlockHash;
        bytes32 transactionsRoot;
        bytes32 crossStatesRoot;
        bytes32 blockRoot;
        bytes consensusPayload;
        bytes20 nextBookkeeper;
    }

    struct ToMerkleValue {
        bytes  txHash;  // cross chain txhash
        uint64 fromChainID;
        TxParam makeTxParam;
    }

    struct TxParam {
        bytes txHash; //  source chain txhash
        bytes crossChainId;
        bytes fromContract;
        uint64 toChainId;
        bytes toContract;
        bytes method;
        bytes args;
    }

    uint constant POLYCHAIN_PUBKEY_LEN = 67;
    uint constant POLYCHAIN_SIGNATURE_LEN = 65;

    /* @notice                  Verify Poly chain transaction whether exist or not
    *  @param _auditPath        Poly chain merkle proof
    *  @param _root             Poly chain root
    *  @return                  The verified value included in _auditPath
    */
    function merkleProve(bytes memory _auditPath, bytes32 _root) internal view returns (bytes memory) {

        uint256 off = 0;
        bytes memory value;
        (value, off)  = ZeroCopySource.NextVarBytes(_auditPath, off);

//        console.log("ECCUtils merkleProve _auditPath ");
//        console.logBytes(_auditPath);
//        console.log("ECCUtils merkleProve _root ");
//        console.logBytes32(_root);

        bytes32 hash = Utils.hashLeaf(value);
//        console.log("ECCUtils merkleProve hash ");
//        console.logBytes(value);
//        console.logBytes32(hash);
        uint size = _auditPath.length.sub(off).div(33);
        bytes32 nodeHash;
        byte pos;
        for (uint i = 0; i < size; i++) {
            (pos, off) = ZeroCopySource.NextByte(_auditPath, off);
            (nodeHash, off) = ZeroCopySource.NextHash(_auditPath, off);
            if (pos == 0x00) {
//                console.log("ECCUtils merkleProve pos == 0x00 ");
//                console.logBytes32(hash);
//                console.logBytes32(nodeHash);
                hash = Utils.hashChildren(nodeHash, hash);
//                console.logBytes32(hash);
            } else if (pos == 0x01) {
//                console.log("ECCUtils merkleProve pos == 0x01 ");
//                console.logBytes32(hash);
//                console.logBytes32(nodeHash);
                hash = Utils.hashChildren(hash, nodeHash);
//                console.logBytes32(hash);
            } else {
                revert("merkleProve, NextByte for position info failed");
            }
        }
        require(hash == _root, "merkleProve, expect root is not equal actual root");
//        console.log("ECCUtils merkleProve value ");
//        console.logBytes(value);
        return value;
    }

    /* @notice              calculate next book keeper according to public key list
    *  @param _keyLen       consensus node number
    *  @param _m            minimum signature number
    *  @param _pubKeyList   consensus node public key list
    *  @return              two element: next book keeper, consensus node signer addresses
    */
    function _getBookKeeper(uint _keyLen, uint _m, bytes memory _pubKeyList) internal view returns (bytes20, address[] memory){
         bytes memory buff;
//        console.log("ECCUtils _getBookKeeper _keyLen %s ", _keyLen);
//        console.log("ECCUtils _getBookKeeper _m %s ", _m);
//        console.log("ECCUtils _getBookKeeper _pubKeyList ");
//        console.logBytes(_pubKeyList);
         buff = ZeroCopySink.WriteUint16(uint16(_keyLen));
//        console.log("ECCUtils _getBookKeeper buff ");
//        console.logBytes(buff);
         address[] memory keepers = new address[](_keyLen);
         bytes32 hash;
         bytes memory publicKey;
         for(uint i = 0; i < _keyLen; i++){
             console.log("ECCUtils _getBookKeeper at %s ", i);
             publicKey = Utils.slice(_pubKeyList, i*POLYCHAIN_PUBKEY_LEN, POLYCHAIN_PUBKEY_LEN);
//             console.logBytes(publicKey);
             buff =  abi.encodePacked(buff, ZeroCopySink.WriteVarBytes(Utils.compressMCPubKey(publicKey)));
//             console.logBytes(Utils.compressMCPubKey(publicKey));
//             console.logBytes(buff);
             hash = keccak256(Utils.slice(publicKey, 3, 64));
//             console.logBytes32(hash);
             keepers[i] = address(uint160(uint256(hash)));
             console.log("ECCUtils _getBookKeeper keepers[%s] %s ", i, keepers[i]);
         }

         buff = abi.encodePacked(buff, ZeroCopySink.WriteUint16(uint16(_m)));
//        console.log("ECCUtils _getBookKeeper buff ");
//        console.logBytes(buff);
         bytes20  nextBookKeeper = ripemd160(abi.encodePacked(sha256(buff)));
//        console.log("ECCUtils _getBookKeeper nextBookKeeper ");
//        console.logBytes20(nextBookKeeper);
         return (nextBookKeeper, keepers);
    }

    /* @notice              Verify public key derived from Poly chain
    *  @param _pubKeyList   serialized consensus node public key list
    *  @param _sigList      consensus node signature list
    *  @return              return two element: next book keeper, consensus node signer addresses
    */
    function verifyPubkey(bytes memory _pubKeyList) internal view returns (bytes20, address[] memory) {
//        console.log("ECCUtils verifyPubkey  _pubKeyList ");
//        console.logBytes(_pubKeyList);
        require(_pubKeyList.length % POLYCHAIN_PUBKEY_LEN == 0, "_pubKeyList length illegal!");
        uint n = _pubKeyList.length / POLYCHAIN_PUBKEY_LEN;
        require(n >= 1, "too short _pubKeyList!");

        bytes20  nextBookKeeper;
        address[] memory keepers;
        (nextBookKeeper, keepers) = _getBookKeeper(n, n - (n - 1) / 3, _pubKeyList);
//        console.log("ECCUtils verifyPubkey  nextBookKeeper ");
//        console.logBytes20(nextBookKeeper);
//        for(uint i = 0; i < keepers.length; i++){
//            console.log("ECCUtils verifyPubkey  keepers %s ", keepers[i]);
//        }
        return (nextBookKeeper, keepers);
    }

    /* @notice              Verify Poly chain consensus node signature
    *  @param _rawHeader    Poly chain block header raw bytes
    *  @param _sigList      consensus node signature list
    *  @param _keepers      addresses corresponding with Poly chain book keepers' public keys
    *  @param _m            minimum signature number
    *  @return              true or false
    */
    function verifySig(bytes memory _rawHeader, bytes memory _sigList, address[] memory _keepers, uint _m) internal view returns (bool){
//        console.log("ECCUtils verifySig _rawHeader ");
//        console.logBytes(_rawHeader);
//        console.log("ECCUtils verifySig _sigList ");
//        console.logBytes(_sigList);
//        for (uint i = 0; i < _keepers.length; i++) {
//            console.log("ECCUtils verifySig _keepers %s", _keepers[i]);
//        }
//        console.log("ECCUtils verifySig _m %s", _m);


        bytes32 hash = getHeaderHash(_rawHeader);
//        console.log("ECCUtils verifySig hash ");
//        console.logBytes32(hash);

        uint sigCount = _sigList.length.div(POLYCHAIN_SIGNATURE_LEN);
//        console.log("ECCUtils verifySig sigCount %s", sigCount);
        address[] memory signers = new address[](sigCount);
        bytes32 r;
        bytes32 s;
        uint8 v;
        for(uint j = 0; j  < sigCount; j++){
            r = Utils.bytesToBytes32(Utils.slice(_sigList, j*POLYCHAIN_SIGNATURE_LEN, 32));
            s =  Utils.bytesToBytes32(Utils.slice(_sigList, j*POLYCHAIN_SIGNATURE_LEN + 32, 32));
            v =  uint8(_sigList[j*POLYCHAIN_SIGNATURE_LEN + 64]) + 27;
            signers[j] =  ecrecover(sha256(abi.encodePacked(hash)), v, r, s);
//            console.log("ECCUtils verifySig r ");
//            console.logBytes32(r);
//            console.log("ECCUtils verifySig s ");
//            console.logBytes32(s);
//            console.log("ECCUtils verifySig v %s", v);
//            console.log("ECCUtils verifySig signers[%s] %s", j, signers[j]);
            if (signers[j] == address(0)) return false;
        }
        return Utils.containMAddresses(_keepers, signers, _m);
    }
    

    /* @notice               Serialize Poly chain book keepers' info in Ethereum addresses format into raw bytes
    *  @param keepersBytes   The serialized addresses
    *  @return               serialized bytes result
    */
    function serializeKeepers(address[] memory keepers) internal view returns (bytes memory) {
        console.log("ECCUtils serializeKeepers  keepers ");
        for (uint i = 0; i < keepers.length; i++) {
//            console.log("ECCUtils serializeKeepers keepers %s", keepers[i]);
        }
//        console.logBytes(_pubKeyList);
        uint256 keeperLen = keepers.length;
        bytes memory keepersBytes = ZeroCopySink.WriteUint64(uint64(keeperLen));
        for(uint i = 0; i < keeperLen; i++) {
            keepersBytes = abi.encodePacked(keepersBytes, ZeroCopySink.WriteVarBytes(Utils.addressToBytes(keepers[i])));
        }
//        console.log("ECCUtils serializeKeepers keepersBytes ");
//        console.logBytes(keepersBytes);
        return keepersBytes;
    }

    /* @notice               Deserialize bytes into Ethereum addresses
    *  @param keepersBytes   The serialized addresses derived from Poly chain book keepers in bytes format
    *  @return               addresses
    */
    function deserializeKeepers(bytes memory keepersBytes) internal view returns (address[] memory) {
//        console.log("ECCUtils deserializeKeepers  keepersBytes ");
//        console.logBytes(keepersBytes);
        uint256 off = 0;
        uint64 keeperLen;
        (keeperLen, off) = ZeroCopySource.NextUint64(keepersBytes, off);
        address[] memory keepers = new address[](keeperLen);
        bytes memory keeperBytes;
        for(uint i = 0; i < keeperLen; i++) {
            (keeperBytes, off) = ZeroCopySource.NextVarBytes(keepersBytes, off);
            keepers[i] = Utils.bytesToAddress(keeperBytes);
//            console.log("ECCUtils deserializeKeepers keepers[i] %s", keepers[i]);
        }
        return keepers;
    }

    /* @notice               Deserialize Poly chain transaction raw value
    *  @param _valueBs       Poly chain transaction raw bytes
    *  @return               ToMerkleValue struct
    */
    function deserializeMerkleValue(bytes memory _valueBs) internal view returns (ToMerkleValue memory) {
        ToMerkleValue memory toMerkleValue;
        uint256 off = 0;
        console.log("ECCUtils deserializeMerkleValue _valueBs ");
        console.logBytes(_valueBs);

        (toMerkleValue.txHash, off) = ZeroCopySource.NextVarBytes(_valueBs, off);
        console.logBytes(toMerkleValue.txHash);

        (toMerkleValue.fromChainID, off) = ZeroCopySource.NextUint64(_valueBs, off);
        console.log("ECCUtils deserializeMerkleValue toMerkleValue.fromChainID %s ", toMerkleValue.fromChainID);

        TxParam memory txParam;

        (txParam.txHash, off) = ZeroCopySource.NextVarBytes(_valueBs, off);
        console.logBytes(txParam.txHash);
        
        (txParam.crossChainId, off) = ZeroCopySource.NextVarBytes(_valueBs, off);
        console.logBytes(txParam.crossChainId);

        (txParam.fromContract, off) = ZeroCopySource.NextVarBytes(_valueBs, off);
        console.logBytes(txParam.fromContract);

        (txParam.toChainId, off) = ZeroCopySource.NextUint64(_valueBs, off);
        console.log("ECCUtils deserializeMerkleValue txParam.toChainId %s ", txParam.toChainId);

        (txParam.toContract, off) = ZeroCopySource.NextVarBytes(_valueBs, off);
        console.logBytes(txParam.toContract);

        (txParam.method, off) = ZeroCopySource.NextVarBytes(_valueBs, off);
        console.logBytes(txParam.method);

        (txParam.args, off) = ZeroCopySource.NextVarBytes(_valueBs, off);
        console.logBytes(txParam.args);

        toMerkleValue.makeTxParam = txParam;

        return toMerkleValue;
    }

    /* @notice            Deserialize Poly chain block header raw bytes
    *  @param _valueBs    Poly chain block header raw bytes
    *  @return            Header struct
    */
    function deserializeHeader(bytes memory _headerBs) internal pure returns (Header memory) {
        Header memory header;
        uint256 off = 0;
        (header.version, off)  = ZeroCopySource.NextUint32(_headerBs, off);

        (header.chainId, off) = ZeroCopySource.NextUint64(_headerBs, off);

        (header.prevBlockHash, off) = ZeroCopySource.NextHash(_headerBs, off);

        (header.transactionsRoot, off) = ZeroCopySource.NextHash(_headerBs, off);

        (header.crossStatesRoot, off) = ZeroCopySource.NextHash(_headerBs, off);

        (header.blockRoot, off) = ZeroCopySource.NextHash(_headerBs, off);

        (header.timestamp, off) = ZeroCopySource.NextUint32(_headerBs, off);

        (header.height, off) = ZeroCopySource.NextUint32(_headerBs, off);

        (header.consensusData, off) = ZeroCopySource.NextUint64(_headerBs, off);

        (header.consensusPayload, off) = ZeroCopySource.NextVarBytes(_headerBs, off);

        (header.nextBookkeeper, off) = ZeroCopySource.NextBytes20(_headerBs, off);

        return header;
    }

    /* @notice            Deserialize Poly chain block header raw bytes
    *  @param rawHeader   Poly chain block header raw bytes
    *  @return            header hash same as Poly chain
    */
    function getHeaderHash(bytes memory rawHeader) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(sha256(rawHeader)));
    }
}