// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IProperty.sol";

interface IPresaledFactory {
    function createPresale(
        string memory _name,
        string memory _symbol,
        uint256 count_,
        bytes32 _salt,
        address operator_,
        address routerAddress_
    ) external returns (address);
}
