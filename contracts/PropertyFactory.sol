// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Property.sol";
import "../interfaces/IProperty.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PropertyFactory is Ownable {
    function createProperty(
        string memory _name,
        string memory _symbol,
        bytes32 _salt,
        address operator_,
        address routerAddress_,
        uint256 count_
    ) public payable onlyOwner returns (address) {
        address propertyAddress = address(new Property{salt: _salt}(_name, _symbol, operator_, routerAddress_, count_));
        Property(propertyAddress).transferOwnership(msg.sender);
        return propertyAddress;
    }
}
