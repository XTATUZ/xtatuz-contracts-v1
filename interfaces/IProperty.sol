// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IProperty {
    enum PropertyStatus {
        INCOMPLETE,
        COMPLETE
    }

    function isMintedMaster() external view returns (bool);

    function propertyStatus() external view returns (PropertyStatus);

    function mintMaster() external;

    function burnMaster() external;

    function mintFragment(address to, uint256[] memory tokenIdList) external;

    function defragment() external;

    function setPropertyStatus(PropertyStatus status) external;

    function setBaseURI(string memory baseURI_) external;

    function getTokenIdList(address member) external view returns (uint256[] memory);

    function tokenURI(uint256 tokenId_) external returns (string memory);

    function setTokenURI(uint256 tokenId_, string memory tokenURI_) external;

    function operatorBurning(uint256[] memory tokenIdList_) external;

    function setOperator(address operator_) external;

    function transferOwnership(address owner) external;

    function setApprovalForAll(address operator, bool approved) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function isApprovedForAll(address owner, address operator) external view returns (bool);

    function ownerOf(uint256 tokenId) external view returns (address);
}
