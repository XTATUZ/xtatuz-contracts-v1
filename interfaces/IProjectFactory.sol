// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IProjectFactory {
    struct CreateProject {
        uint256 projectId_;
        address spv_;
        address trustee_;
        uint256 count_;
        uint256 underwriteCount_;
        address tokenAddress_;
        address propertyAddress_;
        address presaledAddress_;
        uint256 startPresale_;
        uint256 endPresale_;
    }

    function createProject(CreateProject memory) external returns (address);
}