pragma solidity ^0.5.0;

import "./interface/IEthCrossChainManagerProxy.sol";

contract CCMPMock is IEthCrossChainManagerProxy {

    address public tunnelCCM;

    constructor(address _tunnelCCM) public {
        tunnelCCM = _tunnelCCM;
    }

    function getEthCrossChainManager() public view returns (address) {
        return tunnelCCM;
    }
    
}