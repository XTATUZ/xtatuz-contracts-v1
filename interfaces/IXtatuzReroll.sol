// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IXtatuzReroll {
    function _operator() external returns (address);

    function tokenAddress() external returns (address);

    function rerollFee() external returns (uint256);

    function getRerollData(uint256 projectId) external returns (string[] memory);

    function setRerollData(uint256 projectId_, string[] memory rerollData_) external;

    function setFee(uint256 fee_) external;
}
