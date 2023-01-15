// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IProperty.sol";

interface IXtatuzRouter {

    enum CollectionType {
        PRESALE,
        PROPERTY
    }

    struct Collection {
        address contractAddress;
        uint256[] tokenIdList;
        CollectionType collectionType;
    }

    function createProject( //
        uint256 count_,
        uint256 underwriteCount_,
        address tokenAddress_,
        string memory name_,
        string memory symbol_,
        uint256 startPresale_,
        uint256 endPresale_
    ) external;

    function addProjectMember( //
        uint256 projectId_,
        uint256[] memory nftList_,
        string memory referral_
    ) external;

    function claim(uint256 projectId_) external;

    function refund(uint256 projectId) external;

    function nftReroll(uint256 projectId_, uint256 tokenId_) external;

    function claimRerollFee(uint256 projectId_) external;

    function isMemberClaimed(address member_, uint256 projectId_) external view returns (bool);

    function referralAddress() external view returns (address);

    function refferalAmount(string memory referral_) external returns(uint256);

    function getProjectAddressById(uint256 projectId) external view returns (address);

    function getMembershipAddress() external view returns (address);

    function getAllCollection() external returns(Collection[] memory);

    function setRerollAddress(address rerollAddress_) external;

    function setReferralAddress(address referralAddress_) external;

    function setPropertyStatus(uint256 projectId_, IProperty.PropertyStatus status) external;

    function _transferSpv(address newSpv_) external;

    function noticeReply(uint256 projectId_) external;

    function noticeToInactiveWallet(uint256 projectId_, address inactiveWallet_) external;

    function pullbackInactive(uint256 projectId_, address inactiveWallet_) external;
}
