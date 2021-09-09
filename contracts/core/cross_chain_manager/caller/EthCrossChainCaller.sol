pragma solidity ^0.5.0;

import "../libs/upgradeability/InitializableAdminUpgradeabilityProxy.sol";

contract EthCrossChainCaller is InitializableAdminUpgradeabilityProxy{
}

contract CallerImplemetationMock {
    
    address constant ccm = 0xD7ACd2a9FD159E69Bb102A1ca21C9a3e3A5F771B;
    bytes4 constant crossChainSelector = 0xbd5cf625; //"crossChain(uint64,bytes,bytes,bytes)": "bd5cf625",
    event Unlock(address ccm, bytes args, bytes fromContract, uint64 fromChainId);
    
    function lock(bytes memory args) public {
        (bool success,) = ccm.call(abi.encodeWithSelector(crossChainSelector,2,addressToBytes(address(this)),"unlock",args));
        require(success,"call ccm failed");
    }
    
    function unlock(bytes memory args, bytes memory fromContract, uint64 fromChainId) public returns(bool){
        require(msg.sender==ccm, "unlock caller not cmm");
        emit Unlock(msg.sender, args, fromContract, fromChainId);
    }
    
    function addressToBytes(address _addr) internal pure returns (bytes memory bs){
        assembly {
            bs := mload(0x40)
            mstore(bs, 0x14)
            mstore(add(bs, 0x20), shl(96, _addr))
            mstore(0x40, add(bs, 0x40))
       }
    }
}