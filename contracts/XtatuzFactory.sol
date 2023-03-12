// SPDX-License-Identifier: MIT
pragma solidity  0.8.17;

import "./XtatuzProject.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IPropertyFactory.sol";
import "../interfaces/IPresaledFactory.sol";
import "../interfaces/IProjectFactory.sol";
import "../interfaces/IProperty.sol";
import "../interfaces/IPresaled.sol";
import "../interfaces/IXtatuzFactory.sol";
import "../interfaces/IXtatuzProject.sol";

contract XtatuzFactory is Ownable {
    address[] public allProjectAddress;
    uint256[] public allProjectId;

    mapping(uint256 => address) public getProjectAddress;
    mapping(uint256 => address) public getPresaledAddress;
    mapping(uint256 => address) public getPropertyAddress;

    address private _propertyFactory;
    address private _presaledFactory;
    address private _projectFactory;

    constructor(
        address propertyFactory_,
        address presaledFactory_,
        address projectFactory_
    ) {
        require(propertyFactory_ != address(0), "FACTORY: PROPERTY_ADDRESS_ZERO");
        require(presaledFactory_ != address(0), "FACTORY: PRESALED_ADDRESS_ZERO");
        require(projectFactory_ != address(0), "FACTORY: RPOJECT_ADDRESS_ZERO");
        _propertyFactory = propertyFactory_;
        _presaledFactory = presaledFactory_;
        _projectFactory = projectFactory_;
    }

    function getFactoriesAddress() public view returns(address[] memory){
        address[] memory factories = new address[](3);
        factories[0] = _propertyFactory;
        factories[1] = _presaledFactory;
        factories[2] = _projectFactory;
        return factories;
    }

    function createProjectContract(IXtatuzFactory.ProjectPrepareData memory projectData)
        public
        onlyOwner
        returns (address)
    {
        require(getProjectAddress[projectData.projectId_] == address(0), "FACTORY: PROJECT_EXISTS");
        bytes32 salt = keccak256(abi.encode(block.timestamp, msg.sender));

        IPropertyFactory propertyFactory = IPropertyFactory(_propertyFactory);
        IPresaledFactory presaledFactory = IPresaledFactory(_presaledFactory);
        IProjectFactory projectFactory = IProjectFactory(_projectFactory);

        address propertyAddress = propertyFactory.createProperty(
            projectData.name_,
            projectData.symbol_,
            salt,
            tx.origin, //operator,
            owner(),
            projectData.count_
        );
        address presaledAddress = presaledFactory.createPresale(
            projectData.name_,
            projectData.symbol_,
            projectData.count_,
            salt,
            tx.origin, // operator
            owner()
        );

        IProjectFactory.CreateProject memory projectFactoryData = IProjectFactory.CreateProject({
            projectId_: projectData.projectId_,
            spv_: projectData.spv_,
            trustee_: projectData.trustee_,
            count_: projectData.count_,
            underwriteCount_ : projectData.underwriteCount_,
            tokenAddress_: projectData.tokenAddress_,
            propertyAddress_: propertyAddress,
            presaledAddress_: presaledAddress,
            startPresale_: projectData.startPresale_,
            endPresale_ : projectData.endPresale_
        });
        
        address projectAddress = projectFactory.createProject(projectFactoryData);

        IXtatuzProject(projectAddress).transferOwnership(owner());
        IProperty(propertyAddress).transferOwnership(projectAddress);
        IPresaled(presaledAddress).transferOwnership(projectAddress);

        allProjectId.push(projectData.projectId_);
        allProjectAddress.push(projectAddress);

        getProjectAddress[projectData.projectId_] = projectAddress;
        getPropertyAddress[projectData.projectId_] = propertyAddress;
        getPresaledAddress[projectData.projectId_] = presaledAddress;

        return projectAddress;
    }
}
