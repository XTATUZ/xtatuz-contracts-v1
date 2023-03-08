// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./XtatuzProject.sol";
import "../interfaces/IProjectFactory.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ProjectFactory is Ownable {
    function createProject(
        IProjectFactory.CreateProject memory createData
    ) public payable onlyOwner returns (address) {
        bytes32 salt = keccak256(abi.encode(block.timestamp, msg.sender));
        address projectAddress = address(
            new XtatuzProject{salt: salt}(
                createData.projectId_,
                createData.spv_,
                createData.trustee_,
                createData.count_,
                createData.underwriteCount_,
                createData.tokenAddress_,
                createData.propertyAddress_,
                createData.presaledAddress_,
                createData.startPresale_,
                createData.endPresale_
            )
        );
        XtatuzProject(projectAddress).transferOwnership(msg.sender);
        return projectAddress;
    }
}
