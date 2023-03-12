// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Presaled is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCount;

    address private _operator;
    address private _routerAddress;
    string private baseURI;
    uint256[] public presaleIdList;

    mapping(uint256 => uint256) private _mintedTimestamp; // TokenId => Minted Timestamp

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 count_,
        address operator_,
        address routerAddress_
    ) ERC721(_name, _symbol) {
        _setOperator(operator_);
        _tokenIdCount.increment();
        _routerAddress = routerAddress_;
        presaleIdList = new uint256[](count_);
        for (uint256 index = 0; index < count_; index++) {
            presaleIdList[index] = index + 1;
        }
    }

    modifier onlyOperator() {
        _checkOperator();
        _;
    }

    event Minted(address indexed to, uint256[] nftList, uint256 amount);
    event Burned(uint256[] indexed tokenIdList_);

    function mint(address to, uint256[] memory tokenIdList_) public onlyOwner {
        require(to != address(0), "PRESALED: RECIEVER_ADDRESS_IS_0");
        uint256 amount = tokenIdList_.length;
        for (uint256 index = 0; index < amount; index++) {
            uint256 tokenId = tokenIdList_[index];
            require(tokenId > 0, "PROJECT: NOT_ALLOWED_TO_MINT_MASTER");
            require(_exists(tokenId) == false, "PRESALED: TOKEN_ID_ALREADY_EXITS");
            _safeMint(to, tokenId);
            _mintedTimestamp[tokenId] = block.timestamp;
            _tokenIdCount.increment();
        }
        _setApprovalForAll(to, _operator, true);
        emit Minted(to, tokenIdList_, tokenIdList_.length);
    }

    function burn(uint256[] memory tokenIdList_) public onlyOwner {
        for (uint256 index = 0; index < tokenIdList_.length; index++) {
            _burn(tokenIdList_[index]);
        }
        emit Burned(tokenIdList_);
    }

    function getPresaledOwner(address owner) public view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory tokenList = new uint256[](balance);
        for (uint256 index = 0; index < balance; index++) {
            tokenList[index] = tokenOfOwnerByIndex(owner, index);
        }
        return tokenList;
    }

    function getMintedTimestamp(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId) == true, "PRESALED: TOKEN_NOT_EXITS");
        return _mintedTimestamp[tokenId];
    }

    function setBaseURI(string memory baseURI_) public onlyOperator {
        _setBaseURI(baseURI_);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        return bytes(baseURI).length > 0 ? baseURI : "";
    }

    function _checkOperator() private view {
        require(msg.sender == _operator || msg.sender == owner(), "PRESALED: PERMISSION_DENIED");
    }

    function _setOperator(address operator_) private onlyOperator {
        require(operator_ != address(0), "PRESALED: ADDRESS_ZERO");
        _operator = operator_;
    }

    function _setBaseURI(string memory baseURI_) private {
        baseURI = baseURI_;
    }

    function setOperator(address operator_) external onlyOwner {
        _setOperator(operator_);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
        require(from == address(0) || to == address(0), "PRESALED: UNABLE_TO_TRANSFER");
    }
}
