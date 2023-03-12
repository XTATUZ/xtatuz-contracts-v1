// SPDX-License-Identifier: MIT
pragma solidity  0.8.17;

import "./IProperty.sol";

interface IXtatuzFactory {
    struct ProjectPrepareData {
        uint256 projectId_;
        address spv_;
        address trustee_;
        uint256 count_;
        uint256 underwriteCount_;
        address tokenAddress_;
        address membershipAddress_;
        string name_;
        string symbol_;
        address routerAddress;
        uint256 startPresale_;
        uint256 endPresale_;
    }

    function createProjectContract(ProjectPrepareData memory projectData) external returns (address);

    function getProjectAddress(uint256 projectId_) external view returns (address);

    function getPresaledAddress(uint256 projectId_) external view returns (address);

    function getPropertyAddress(uint256 projectId_) external view returns (address);

    function allProjectAddress() external view returns (address[] memory);

    function allProjectId() external view returns (uint256[] memory);
}
