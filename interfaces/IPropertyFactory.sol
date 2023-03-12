// SPDX-License-Identifier: MIT
pragma solidity  0.8.17;

import "../contracts/Property.sol";
import "./IProperty.sol";

interface IPropertyFactory {
    function createProperty(
        string memory _name,
        string memory _symbol,
        bytes32 _salt,
        address operator_,
        address routerAddress_,
        uint256 count_
    ) external returns (address);
}