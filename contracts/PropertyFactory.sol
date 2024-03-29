// SPDX-License-Identifier: MIT
pragma solidity  0.8.17;

import "./Property.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PropertyFactory is Ownable {
    event CreateProperty(string name, address indexed propertyAddress);

    function createProperty(
        string memory _name,
        string memory _symbol,
        bytes32 _salt,
        address operator_,
        address routerAddress_,
        uint256 count_
    ) public onlyOwner returns (address) {
        address propertyAddress = address(new Property{salt: _salt}(_name, _symbol, operator_, routerAddress_, count_));
        Property(propertyAddress).transferOwnership(msg.sender);
        emit CreateProperty(_name, propertyAddress);
        return propertyAddress;
    }
}
