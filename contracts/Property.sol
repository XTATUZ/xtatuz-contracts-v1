// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interfaces/IProperty.sol";

contract Property is ERC721Enumerable, Ownable {
    using Strings for uint256;

    constructor(
        string memory name_,
        string memory symbol_,
        address operator_,
        address routerAddress_,
        uint256 count_
    ) ERC721(name_, symbol_) {
        _setOperator(operator_);
        setPropertyStatus(IProperty.PropertyStatus.INCOMPLETE);
        _routerAddress = routerAddress_;
        count = count_;
    }

    address public _operator;
    address public _routerAddress;
    string public baseURI;
    bool public isMintedMaster;
    uint256 public count;
    IProperty.PropertyStatus public propertyStatus;

    mapping(uint256 => string) private _tokenURIs;

    modifier onlyOperator() {
        _checkOperator();
        _;
    }

    event MasterMinted(address operator);
    event MasterBurned(address operator);
    event MintFragment(address indexed to, uint256[] tokenIdList);
    event Defragment(address indexed fragmentsOwner);
    event SetPropertyStatus(IProperty.PropertyStatus prevStatus, IProperty.PropertyStatus newStatus);
    event SetOperator(address prevOperator, address newOperator);
    event SetBaseURI(string prevBaseURI, string newBaseURI);
    event SetTokenURI(uint256 tokenId, string prevTokenURI, string newTokenURI);

    function mintMaster() public onlyOwner {
        require(isMintedMaster == false, "PROPERTY: MASTER_MINTED");
        _mint(address(this), 0);
        isMintedMaster = true;
        emit MasterMinted(msg.sender);
    }

    function burnMaster() public onlyOwner {
        require(isMintedMaster == true, "PROPERTY: NO_MASTER_NFT");
        uint256 totalSupply = totalSupply();
        if (totalSupply > 1) {
            require(balanceOf(address(this)) == count + 1, "PROPERTY_FRAGMENTED");
        }
        require(ownerOf(0) == address(this), "CONTRACT_IS_NOT_MASTER_OWNER");
        isMintedMaster = false;
        _burn(0);
        emit MasterBurned(msg.sender);
    }

    function mintFragment(address to, uint256[] memory tokenIdList) public onlyOwner {
        require(ownerOf(0) == address(this), "PROPERTY: NO_MASTER_NFT");
        require(isMintedMaster == true, "PROPERTY: MASTER_NOT_MINTED");
        uint256 amount = tokenIdList.length;
        for (uint256 index = 0; index < amount; index++) {
            uint256 tokenId = tokenIdList[index];
            require(_exists(tokenId) == false, "PROPERTY: TOKEN_ALREADY_EXITS");
            _safeMint(to, tokenId);
        }
        _setApprovalForAll(to, _routerAddress, true);
        emit MintFragment(to, tokenIdList);
    }

    function defragment() public {
        require(balanceOf(msg.sender) == count, "PROPERTY: ONLY_ALL_FRAGMENT_OWNER");
        for (uint256 i = 1; i <= count; i++) {
            _burn(i);
        }
        _approve(msg.sender, 0);
        safeTransferFrom(address(this), tx.origin, 0);
        emit Defragment(msg.sender);
    }

    function setPropertyStatus(IProperty.PropertyStatus status) public onlyOperator {
        IProperty.PropertyStatus prevStatus = propertyStatus;
        propertyStatus = status;
        emit SetPropertyStatus(prevStatus, status);
    }

    function _setOperator(address operator_) private onlyOperator {
        require(operator_ != address(0), "PROPERTY: OPERATOR_ADDRESS_ZERO");
        address prevOperator = _operator;
        _operator = operator_;
        emit SetOperator(prevOperator, operator_);
    }

    function setBaseURI(string memory baseURI_) public onlyOperator {
        string memory prevBaseURI = baseURI;
        baseURI = baseURI_;
        emit SetBaseURI(prevBaseURI, baseURI_);
    }

    function getTokenIdList(address member) public view returns (uint256[] memory) {
        uint256 balance = balanceOf(member);
        uint256[] memory tokenList = new uint256[](balance);
        for (uint256 index = 0; index < balance; index++) {
            tokenList[index] = tokenOfOwnerByIndex(member, index);
        }
        return tokenList;
    }

    function tokenURI(uint256 tokenId_) public view virtual override returns (string memory) {
        _requireMinted(tokenId_);

        string memory _tokenURI = _tokenURIs[tokenId_];
        string memory base = _baseURI();

        if (bytes(_tokenURI).length > 0) {
            return _tokenURI;
        } else {
            return string(abi.encodePacked(base, tokenId_.toString()));
        }
    }

    function setTokenURI(uint256 tokenId_, string memory tokenURI_) public onlyOperator {
        require(_exists(tokenId_), "PROPERTY: NOT_EXIST_TOKEN_ID");
        string memory prevTokenURI = _tokenURIs[tokenId_];
        _tokenURIs[tokenId_] = tokenURI_;
        emit SetTokenURI(tokenId_, prevTokenURI, tokenURI_);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function _checkOperator() private view {
        require(
            msg.sender == _operator || msg.sender == owner() || msg.sender == _routerAddress,
            "PROPERTY: ONLY_OPERTOR"
        );
    }

    function operatorBurning(uint256[] memory tokenIdList_) public onlyOperator {
        for (uint256 i = 0; i < tokenIdList_.length; ++i) {
            require(ownerOf(tokenIdList_[i]) == msg.sender, "PROPERTY: ONLY_OWNED_BY_OPERATOR");
            _burn(tokenIdList_[i]);
        }
    }

    function setOperator(address operator_) external onlyOwner {
        _setOperator(operator_);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721) {
        super._afterTokenTransfer(from, to, tokenId);
        _setApprovalForAll(to, _routerAddress, true);
    }
}
