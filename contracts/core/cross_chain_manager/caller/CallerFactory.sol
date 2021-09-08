pragma solidity ^0.5.0;

import "../libs/upgradeability/ProxyFactory.sol";
import "../libs/upgradeability/InitializableAdminUpgradeabilityProxy.sol";

contract CallerFactory is ProxyFactory{
    
    mapping(address => bool) private children;
    
    function isChild(address _addr) public view returns(bool) {
        return children[_addr];
    }

    function deployMinimal(address _logic, bytes memory _data)  public returns(address proxy) {
        proxy = super.deployMinimal(_logic, _data); 
        children[proxy] = true; 
    } 

    function deploy(uint256 _salt, address _logic, address _admin, bytes memory _data) public returns (address proxy) {
        proxy = super.deploy(_salt, _logic, _admin, _data); 
        children[proxy] = true; 
    }

    function deploySigned(uint256 _salt, address _logic, address _admin, bytes memory _data, bytes memory _signature) public returns (address proxy) {
        proxy = super.deploySigned(_salt, _logic, _admin, _data, _signature); 
        children[proxy] = true;
    }
}