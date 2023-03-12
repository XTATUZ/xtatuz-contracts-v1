// SPDX-License-Identifier: MIT
pragma solidity  0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../interfaces/IXtatuzFactory.sol";
import "../interfaces/IXtatuzProject.sol";
import "../interfaces/IPresaled.sol";
import "../interfaces/IProperty.sol";
import "../interfaces/IXtatuzReroll.sol";
import "../interfaces/IXtatuzReferral.sol";

contract XtatuzRouter {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    Counters.Counter private _projectIdCounter;

    IXtatuzFactory private _xtatuzFactory;

    address public _spvAddress;
    address public _xtatuzFactoryAddress;
    address public _membershipAddress;
    address public _rerollAddress;
    address public _referralAddress;
    uint256 public constant PULLBACK_PERIOD = 30 days;
    mapping(uint256 => mapping(address => uint256)) public isNoticeTimestamp;

    enum CollectionType {
        PRESALE,
        INCOMPLETE,
        COMPLETE
    }

    struct Collection {
        address contractAddress;
        uint256[] tokenIdList;
        CollectionType collectionType;
    }

    mapping(address => uint256[]) private _memberdProject;
    mapping(address => mapping(uint256 => bool)) private _isMemberClaimed;
    mapping(uint256 => uint256) private _totalRerollFee;
    mapping(uint256 => mapping(address => bool)) public _isNotice;

    constructor(address spv_, address factoryAddress_) {
        require(spv_ != address(0) && factoryAddress_ != address(0), "ROUTER: INVALID ADDRESS");
        _transferSpv(spv_);
        _xtatuzFactory = IXtatuzFactory(factoryAddress_);
        _projectIdCounter.increment();
    }

    event SpvTransferred(address indexed prevSpv, address indexed newSpv);
    event CreatedProject(uint256 indexed projectId, address indexed projectAddress);
    event AddProjectMember(
        uint256 indexed projectId,
        address indexed member,
        string indexed referral,
        uint256 totalPrice
    );
    event Claimed(uint256 indexed projectId, address member);
    event Refunded(uint256 indexed projectId, address member);
    event ChangePropertyStatus(uint256 indexed projectId, IProperty.PropertyStatus prevStatus, IProperty.PropertyStatus newStatus);
    event NFTReroll(address indexed member, uint256 projectId, uint256 tokenId);
    event ClaimedRerollFee(address indexed spv, uint256 projectId, uint256 amount);
    event PullbackInactive(uint256 indexed projectId, address inactiveWallet_);
    event NoticeReply(uint256 indexed projectId, address indexed inactiveWallet_, uint256 noticeTimestamp);
    event NoticeToInactiveWallet(uint256 indexed projectId, address indexed inactiveWallet_, uint256 noticeTimestamp);
    event SetRerollAddress(address prevAddress, address newAddress);
    event SetMembershipAddress(address prevAddress, address newAddress);
    event SetReferralAddress(address prevAddress, address newAddress);

    modifier onlySpv() {
        require(_spvAddress == msg.sender, "ROUTER: ONLY_SPV");
        _;
    }

    modifier prohibitZeroAddress(address caller) {
        require(caller != address(0), "ROUTER: ADDRESS_0");
        _;
    }

    function createProject(
        uint256 count_,
        uint256 underwriteCount_,
        address tokenAddress_,
        string memory name_,
        string memory symbol_,
        uint256 startPresale_,
        uint256 endPresale_
    ) public onlySpv {
        uint256 projectId = _projectIdCounter.current();
        require(startPresale_ >= block.timestamp - 1000, "ROUTER: INVALID_START_DATE");
        require(endPresale_ > startPresale_, "ROUTER: INVALID_END_DATE");

        uint256 totalSupply = IERC20(tokenAddress_).totalSupply();
        require(totalSupply > 0, "ROUTER: INVALID_TOKEN");

        _projectIdCounter.increment();
        IXtatuzFactory.ProjectPrepareData memory data = IXtatuzFactory.ProjectPrepareData({
            projectId_: projectId,
            spv_: msg.sender,
            trustee_: msg.sender,
            count_: count_,
            underwriteCount_: underwriteCount_,
            tokenAddress_: tokenAddress_,
            membershipAddress_: _membershipAddress,
            name_: name_,
            symbol_: symbol_,
            routerAddress: address(this),
            startPresale_: startPresale_,
            endPresale_: endPresale_
        });
        address projectAddress = _xtatuzFactory.createProjectContract(data);
        emit CreatedProject(projectId, projectAddress);
    }

    function addProjectMember(
        uint256 projectId_,
        uint256[] memory nftList_,
        string memory referral_
    ) public {
        uint256 amount = nftList_.length;
        address projectAddress = _xtatuzFactory.getProjectAddress(projectId_);
        IXtatuzProject project = IXtatuzProject(projectAddress);
        uint256 price = project.addProjectMember(msg.sender, nftList_);

        uint256 minPrice = project.minPrice();
        IXtatuzReferral referralContract = IXtatuzReferral(_referralAddress);
        referralContract.increaseBuyerRef(projectId_, referral_, amount * minPrice);

        address tokenAddress = project.tokenAddress();

        uint256[] memory memberedProject = _memberdProject[msg.sender];
        bool foundedIndex;
        for (uint256 index = 0; index < memberedProject.length; index++) {
            if (memberedProject[index] == projectId_) {
                foundedIndex = true;
            }
        }
        if (!foundedIndex) {
            _memberdProject[msg.sender].push(projectId_);
        }

        _isMemberClaimed[msg.sender][projectId_] = false;
        IERC20(tokenAddress).safeTransferFrom(msg.sender, projectAddress, price);
        emit AddProjectMember(projectId_, msg.sender, referral_, price);
    }

    function claim(uint256 projectId_) public {
        require(_isMemberClaimed[msg.sender][projectId_] == false, "ROUTER: ALREADY_CLAIMED");

        _isMemberClaimed[msg.sender][projectId_] = true;

        address projectAddress = _xtatuzFactory.getProjectAddress(projectId_);
        IXtatuzProject(projectAddress).claim(msg.sender);

        emit Claimed(projectId_, msg.sender);
    }

    function refund(uint256 projectId_) public {
        uint256[] memory memberedProject = _memberdProject[msg.sender];
        address projectAddress = _xtatuzFactory.getProjectAddress(projectId_);

        for (uint256 index = 0; index < memberedProject.length; index++) {
            if (memberedProject[index] == projectId_) {
                delete _memberdProject[msg.sender][index];
            }
        }

        IXtatuzProject(projectAddress).refund(msg.sender);

        emit Refunded(projectId_, msg.sender);
    }

    function nftReroll(uint256 projectId_, uint256 tokenId_) public {
        require(_rerollAddress != address(0), "ROUTER: NO_REROLL_ADDRESS");

        address propertyAddress = _xtatuzFactory.getPropertyAddress(projectId_);
        IProperty property = IProperty(propertyAddress);
        IXtatuzReroll rerollContract = IXtatuzReroll(_rerollAddress);

        address tokenAddress = rerollContract.tokenAddress();
        string memory prevUri = property.tokenURI(tokenId_);
        uint256 fee = rerollContract.rerollFee();
        string[] memory rerollData = rerollContract.getRerollData(projectId_);
        require(rerollData.length > 0, "ROUTER: NO_REROLL_DATA");
        address tokenOwner = property.ownerOf(tokenId_);
        require(tokenOwner == msg.sender, "ROUTER: NOT_NFT_OWNER");

        uint256 newIndex = block.timestamp % rerollData.length;
        property.setTokenURI(tokenId_, rerollData[newIndex]);
        rerollData[newIndex] = prevUri;
        rerollContract.setRerollData(projectId_, rerollData);
        
        _totalRerollFee[projectId_] += fee;
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), fee);

        emit NFTReroll(msg.sender, projectId_, tokenId_);
    }

    function claimRerollFee(uint256 projectId_) public onlySpv {
        require(_totalRerollFee[projectId_] > 0, "ROUTER: OUT_OF_FEE");

        IXtatuzReroll rerollContract = IXtatuzReroll(_rerollAddress);
        address tokenAddress = rerollContract.tokenAddress();

        uint256 totalFee = _totalRerollFee[projectId_];
        _totalRerollFee[projectId_] = 0;
        IERC20(tokenAddress).safeTransfer(msg.sender, totalFee);
        emit ClaimedRerollFee(msg.sender, projectId_, totalFee);
    }

    function isMemberClaimed(address member_, uint256 projectId_) public view returns (bool) {
        return _isMemberClaimed[member_][projectId_];
    }

    function referralAddress() public view returns (address) {
        return _referralAddress;
    }

    function getProjectAddressById(uint256 projectId) public view returns (address) {
        return _xtatuzFactory.getProjectAddress(projectId);
    }

    function getAllCollection() public view returns (Collection[] memory) {
        uint256[] memory projectList = _memberdProject[msg.sender];
        Collection[] memory collections = new Collection[](projectList.length);
        for (uint256 index = 0; index < projectList.length; index++) {
            if (projectList[index] > 0) {
                uint256 projectId = projectList[index];
                address projectAddress = _xtatuzFactory.getProjectAddress(projectId);
                IXtatuzProject.Status status = IXtatuzProject(projectAddress).projectStatus();
                if (status == IXtatuzProject.Status.FINISH && _isMemberClaimed[msg.sender][projectId]) {
                    address propertyAddress = _xtatuzFactory.getPropertyAddress(projectId);
                    uint256[] memory tokenList = IProperty(propertyAddress).getTokenIdList(msg.sender);
                    IProperty.PropertyStatus propStatus = IProperty(propertyAddress).propertyStatus();
                    CollectionType collecType = CollectionType(uint256(propStatus) + 1);
                    Collection memory collect = Collection({
                        contractAddress: propertyAddress,
                        tokenIdList: tokenList,
                        collectionType: collecType
                    });
                    collections[index] = collect;
                } else {
                    address presaledAddress = _xtatuzFactory.getPresaledAddress(projectId);
                    uint256[] memory tokenList = IPresaled(presaledAddress).getPresaledOwner(msg.sender);
                    Collection memory collect = Collection({
                        contractAddress: presaledAddress,
                        tokenIdList: tokenList,
                        collectionType: CollectionType.PRESALE
                    });
                    collections[index] = collect;
                }
            }
        }
        return collections;
    }

    function setRerollAddress(address rerollAddress_) public prohibitZeroAddress(rerollAddress_) onlySpv {
        address prevAddress = _rerollAddress;
        _rerollAddress = rerollAddress_;
        emit SetRerollAddress(prevAddress, rerollAddress_);
    }

    function setMembershipAddress(address membershipAddress_) public prohibitZeroAddress(membershipAddress_) onlySpv {
        address prevAddress = _membershipAddress;
        _membershipAddress = membershipAddress_;
        emit SetMembershipAddress(prevAddress, membershipAddress_);
    }

    function setReferralAddress(address referralAddress_) public prohibitZeroAddress(referralAddress_) onlySpv {
        address prevAddress = _referralAddress;
        _referralAddress = referralAddress_;
        emit SetReferralAddress(prevAddress, referralAddress_);
    }

    function setPropertyStatus(uint256 projectId_, IProperty.PropertyStatus newStatus) public onlySpv {
        address propertyAddress = _xtatuzFactory.getPropertyAddress(projectId_);
        IProperty.PropertyStatus prevStatus = IProperty(propertyAddress).propertyStatus();
        IProperty(propertyAddress).setPropertyStatus(newStatus);
        emit ChangePropertyStatus(projectId_, prevStatus, newStatus);
    }

    function _transferSpv(address newSpv_) internal prohibitZeroAddress(newSpv_) {
        address prevSpv = _spvAddress;
        _spvAddress = newSpv_;
        emit SpvTransferred(prevSpv, newSpv_);
    }

    function transferSpv(address newSpv_) public onlySpv prohibitZeroAddress(newSpv_) {
        _transferSpv(newSpv_);
    }

    function noticeReply(uint256 projectId_) public {
        address projectAddress = _xtatuzFactory.getProjectAddress(projectId_);
        require(projectAddress != address(0), "ROUTER: INVALID_PROJECT_ID");
        _isNotice[projectId_][msg.sender] = false;
        isNoticeTimestamp[projectId_][msg.sender] = block.timestamp;
        emit NoticeReply(projectId_, msg.sender, block.timestamp);
    }

    function noticeToInactiveWallet(uint256 projectId_, address inactiveWallet_) public onlySpv {
        _isNotice[projectId_][inactiveWallet_] = true;
        isNoticeTimestamp[projectId_][inactiveWallet_] = block.timestamp + PULLBACK_PERIOD;
        emit NoticeToInactiveWallet(projectId_, inactiveWallet_, block.timestamp);
    }

    function pullbackInactive(uint256 projectId_, address inactiveWallet_) public onlySpv {
        require(_isNotice[projectId_][inactiveWallet_] == true, "ROUTER: NOTICE_BEFORE");
        require(isNoticeTimestamp[projectId_][inactiveWallet_] < block.timestamp, "ROUTER: IN_NOTICE_PERIOD");
        address propertyAddress = _xtatuzFactory.getPropertyAddress(projectId_);
        IProperty property = IProperty(propertyAddress);
        uint256[] memory nftList = property.getTokenIdList(inactiveWallet_);

        for (uint256 i = 0; i < nftList.length; i++) {
            IERC721(propertyAddress).safeTransferFrom(inactiveWallet_, msg.sender, nftList[i]);
        }

        emit PullbackInactive(projectId_, inactiveWallet_);
    }
}
