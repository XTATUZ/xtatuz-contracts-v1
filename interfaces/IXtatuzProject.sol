// SPDX-License-Identifier: MIT
pragma solidity  0.8.17;

import "./IProperty.sol";

interface IXtatuzProject {
    enum Status {
        AVAILABLE,
        FINISH,
        REFUND,
        UNAVAILABLE
    }

    struct ProjectData {
        uint256 projectId;
        address owner;
        uint256 count;
        uint256 countReserve;
        uint256 underwriteCount;
        uint256 value;
        address[] members;
        uint256 startPresale;
        uint256 endPresale;
        Status status;
        address tokenAddress;
        address propertyAddress;
        address presaledAddress;
    }

    function addProjectMember(address member_, uint256[] memory nftList_) external returns (uint256);

    function finishProject() external;

    function claim(address member_) external;

    function refund(address member_) external;

    function setPresalePeriod(uint256 startPresale_, uint256 endPresale_) external;

    function setUnderwriteCount(uint256 underwriteCount_) external; 

    function getMemberedNFTLists(address member_) external view returns (uint256[] memory);

    function projectStatus() external view returns (Status);

    function minPrice() external returns (uint256);

    function count() external view returns (uint256);

    function countReserve() external view returns (uint256);

    function startPresale() external view returns (uint256);

    function endPresale() external view returns (uint256);

    function tokenAddress() external view returns (address);

    function transferOwnership(address owner) external;

    function transferProjectOwner(address newProjectOwner_) external;

    function transferOperator(address newOperator_) external;

    function transferTrustee(address newTrustee_) external;

    function multiSigMint() external;

    function multiSigBurn() external;

    function getProjectData() external view returns (ProjectData memory);

    function checkCanClaim() external view returns (bool);

    function ownerClaimLeft(uint256[] memory leftNFTList) external;

    function extendEndPresale() external;

    function getUnavailableNFT() external view returns (uint256[] memory);

}
