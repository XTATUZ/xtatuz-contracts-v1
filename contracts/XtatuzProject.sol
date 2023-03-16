// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IProperty.sol";
import "../interfaces/IPresaled.sol";
import "../interfaces/IXtatuzRouter.sol";
import "../interfaces/IXtatuzProject.sol";

contract XtatuzProject is Ownable {
    using SafeERC20 for IERC20;

    address private _operatorAddress;
    address private _trusteeAddress;
    address private _projectOwner;

    address public tokenAddress;
    address private _propertyAddress;
    address private _presaledAddress;

    uint256 public minPrice = 30000 * (10**18);
    uint256 public count;
    uint256 public countReserve;
    uint256 private _underwriteCount;
    uint256 public projectValue;
    uint256 public startPresale;
    uint256 public endPresale;
    uint256 public projectId;
    uint256[] public unavailableNFT;

    bool public checkCanClaim;
    bool public isFinished;
    bool private _isTriggedEndpresale;

    address[] public projectMember;
    mapping(address => bool) public memberExists;
    mapping(address => uint256[]) public getMemberedNFTList;

    mapping(address => bool) private _multiSigMint;
    mapping(address => bool) private _multiSigBurn;

    constructor(
        uint256 projectId_,
        address operator_,
        address trustee_,
        uint256 count_,
        uint256 underwriteCount_,
        address tokenAddress_,
        address propertyAddress_,
        address presaledAddress_,
        uint256 startPresale_,
        uint256 endPresale_
    ) {
        _transferOperator(operator_);
        _transferTrustee(trustee_);
        _initialData(count_, underwriteCount_, tokenAddress_, propertyAddress_, presaledAddress_);
        setPresalePeriod(startPresale_, endPresale_);
        projectId = projectId_;
        _projectOwner = tx.origin;
    }

    event OperatorTransfered(address indexed prevOperator, address indexed newSpv);
    event TrusteeTransferred(address indexed prevTrustee, address indexed newTrustee);
    event ProjectOwnerTransferred(address indexed prevOwner, address indexed newOwner);
    event AddProjectMember(uint256 indexed projectId, address indexed member, uint256 value);
    event FinishProject(uint256 indexed projectId, address xtatuzWallet);
    event SetPresalePeriod(uint256 prevStart, uint256 prevEnd, uint256 newStart, uint256 newEnd);
    event SetUnderwriteCount(uint256 prevValue, uint256 newValue);
    event Claim(address indexed member, uint256[] tokenList);
    event Refund(address indexed member, uint256[] tokenList);
    event ExtendEndPresale(uint256 prevEndPresale, uint256 newEndPresale, uint256 presaledPercent);
    event OwnerClaimLeft(address indexed owner, uint256[] tokenList);
    event MultiSigMint(address indexed signer);
    event MultiSigBurn(address indexed signer);
    event InitialData(uint256 count, uint256 underwriteCount, address tokenAddress, address indexed propertyAddress, address indexed presaledAddress);

    modifier spvAndTrustee() {
        _checkSpvAndTrustee();
        _;
    }

    modifier isFullReserve() {
        _checkIsFullReserve();
        _;
    }

    modifier isLeftReserve() {
        _checkIsLeftReserve();
        _;
    }

    modifier isAvailable() {
        _checkIsAvailable();
        _;
    }

    modifier ProhibitZeroAddress(address caller) {
        _checkProhibitZeroAddress(caller);
        _;
    }

    modifier onlyOperator() {
        _checkOnlyOperator();
        _;
    }

    modifier onlyProjectOwner() {
        checkOnlyProjectOwner();
        _;
    }

    function setPresalePeriod(uint256 startPresale_, uint256 endPresale_) internal onlyOwner {
        require(endPresale_ > startPresale_, "PROJECT: WRONG_END_DATE");
        uint256 prevStart = startPresale;
        uint256 prevEnd = endPresale;
        startPresale = startPresale_;
        endPresale = endPresale_;
        emit SetPresalePeriod(prevStart, prevEnd, startPresale_, endPresale_);
    }

    function setUnderwriteCount(uint256 underwriteCount_) public onlyOperator {
        require(underwriteCount_ < count, "PROJECT: INVALID_COUNT");
        uint256 prevValue = _underwriteCount;
        _underwriteCount = underwriteCount_;
        emit SetUnderwriteCount(prevValue, underwriteCount_);
    }

    function getMemberedNFTLists(address member_) public view returns (uint256[] memory) {
        return getMemberedNFTList[member_];
    }

    function addProjectMember(address member_, uint256[] memory nftList_)
        public
        isAvailable
        isLeftReserve
        onlyOwner
        returns (uint256)
    {
        require(projectStatus() == IXtatuzProject.Status.AVAILABLE, "PROJECT: PROJECT_UNAVIALABLE");
        uint256 amount = nftList_.length;
        require(amount > 0, "PROJECT: ZERO_AMOUNT");
        for (uint256 i = 0; i < amount; ++i) {
            require(nftList_[i] <= count, "PROJECT: ID_OVER_FRAGMENT");
        }
        _checkAvailableNFT(nftList_);

        uint256 price = minPrice * amount;
        projectValue += price;

        _pickupAvailableNFT(nftList_, member_);

        countReserve -= amount;

        if (memberExists[member_] == false) {
            memberExists[member_] = true;
            projectMember.push(member_);
        }

        IPresaled(_presaledAddress).mint(member_, nftList_);
        emit AddProjectMember(projectId, member_, price);

        return price;
    }

    function claim(address member_) public onlyOwner {
        uint256[] memory tokenList = IPresaled(_presaledAddress).getPresaledOwner(member_);
        require(tokenList.length > 0, "PROJECT: TOKENLIST_ZERO");
        require(projectStatus() == IXtatuzProject.Status.FINISH, "PROJECT: PROJECT_UNFINISH");

        IProperty property = IProperty(_propertyAddress);
        IPresaled presaled = IPresaled(_presaledAddress);

        bool isMintedMaster = property.isMintedMaster();
        require(isMintedMaster == true, "PROJECT: MASTER_NOT_MINTED");

        presaled.burn(tokenList);
        property.mintFragment(member_, tokenList);
        emit Claim(member_, tokenList);
    }

    function refund(address member_) public onlyOwner {
        uint256[] memory tokenList = IPresaled(_presaledAddress).getPresaledOwner(member_);
        require(projectStatus() == IXtatuzProject.Status.REFUND, "PROJECT: PROJECT_UNREFUNDED");

        IPresaled(_presaledAddress).burn(tokenList);

        uint256 totalToken = getMemberedNFTList[member_].length * minPrice;
        IERC20(tokenAddress).safeTransfer(member_, totalToken);
        emit Refund(member_, tokenList);
    }

    function finishProject(address xtatuzWallet_) public isFullReserve onlyOperator {
        require(projectStatus() == IXtatuzProject.Status.PREPARE_FINISH, "PROJECT: NOT_READY_TO_FINISH");
        _multiSigMint[msg.sender] = true;
        require(
            _multiSigMint[_operatorAddress] && _multiSigMint[_trusteeAddress],
            "PROJECT: NOT_ALLOWS_BY_MULTISIGMINT"
        );

        isFinished = true;
        checkCanClaim = true;
        IProperty(_propertyAddress).mintMaster();

        address referralAddress = IXtatuzRouter(owner()).referralAddress();
        uint256 referralAmount = (((count - countReserve) * minPrice) * 5) / 100;
        uint256 xtatuzAmount = ((count * minPrice) * 10) / 100;
        IERC20(tokenAddress).safeTransfer(_projectOwner, projectValue - xtatuzAmount);
        IERC20(tokenAddress).safeTransfer(referralAddress, referralAmount);
        IERC20(tokenAddress).safeTransfer(xtatuzWallet_, xtatuzAmount - referralAmount);

        emit FinishProject(projectId, xtatuzWallet_);
    }

    function ownerClaimLeft(uint256[] memory leftNFTList) public onlyProjectOwner {
        require(projectStatus() == IXtatuzProject.Status.FINISH, "PROJECT: PROJECT_UNFINISH");
        _checkAvailableNFT(leftNFTList);
        _pickupAvailableNFT(leftNFTList, msg.sender);
        IPresaled(_presaledAddress).mint(msg.sender, leftNFTList);
        emit OwnerClaimLeft(msg.sender, leftNFTList);
    }

    function multiSigMint() public isFullReserve spvAndTrustee {
        _multiSigMint[msg.sender] = true;
        emit MultiSigMint(msg.sender);
    }

    function multiSigBurn() public isFullReserve spvAndTrustee {
        address masterOwner = IERC721(_propertyAddress).ownerOf(0);
        require(masterOwner == _propertyAddress, "PROJECT: NOT_MASTER_OWNER");

        _multiSigBurn[msg.sender] = true;

        if (_multiSigBurn[_operatorAddress] && _multiSigBurn[_trusteeAddress]) {
            IProperty(_propertyAddress).burnMaster();
            checkCanClaim = false;
        }
        emit MultiSigBurn(msg.sender);
    }

    function extendEndPresale() public onlyOperator {
        require(block.timestamp > (endPresale - 1 days), "PROJECT: NOT_END_PREV");
        require(_isTriggedEndpresale == false, "PROJECT: EXTENDED_PRESALE");
        if (_isTriggedEndpresale == false) {
            _extendEndPresale();
        }
    }

    function projectStatus() public view returns (IXtatuzProject.Status status) {
        if (isFinished) {
            return IXtatuzProject.Status.FINISH;
        } else if (countReserve == 0 || _underwriteCount >= countReserve) {
            return IXtatuzProject.Status.PREPARE_FINISH;
        } else if (block.timestamp > endPresale && countReserve > 0 && !(_underwriteCount >= countReserve)) {
            return IXtatuzProject.Status.REFUND;
        } else if (!isFinished && block.timestamp >= startPresale && block.timestamp <= endPresale) {
            return IXtatuzProject.Status.AVAILABLE;
        } else {
            return IXtatuzProject.Status.UNAVAILABLE;
        }
    }

    function getUnavailableNFT() public view returns (uint256[] memory) {
        return unavailableNFT;
    }

    function getProjectData() public view returns (IXtatuzProject.ProjectData memory) {
        IXtatuzProject.ProjectData memory projectData = IXtatuzProject.ProjectData({
            projectId: projectId,
            owner: _projectOwner,
            count: count,
            countReserve: countReserve,
            underwriteCount: _underwriteCount,
            value: projectValue,
            members: projectMember,
            startPresale: startPresale,
            endPresale: endPresale,
            status: projectStatus(),
            tokenAddress: tokenAddress,
            propertyAddress: _propertyAddress,
            presaledAddress: _presaledAddress
        });
        return projectData;
    }

    function transferProjectOwner(address newProjectOwner_) public onlyProjectOwner {
        _transferProjectOwner(newProjectOwner_);
    }

    function transferOperator(address newOperator_) public onlyOperator {
        _transferOperator(newOperator_);
    }

    function transferTrustee(address newTrustee_) public onlyOperator {
        _transferTrustee(newTrustee_);
    }

    function _extendEndPresale() internal {
        require(
            block.timestamp > (endPresale - 1 days) && block.timestamp < endPresale,
            "PROJECT: ONLY_THE_EXTENDING_PERIOD"
        );
        require(_isTriggedEndpresale == false, "PROJECT: EXTENED_PRESALE");
        uint256 prevEndPresale = endPresale;
        uint256 absoluteCount = count - _underwriteCount;
        uint256 percent = ((count - countReserve) * 100) / absoluteCount;
        if (percent >= 95) {
            endPresale += 5 days;
        } else if (percent >= 85 && percent < 95) {
            endPresale += 10 days;
        } else if (percent >= 65 && percent < 85) {
            endPresale += 15 days;
        } else {
            endPresale += 30 days;
        }
        _isTriggedEndpresale = true;

        emit ExtendEndPresale(prevEndPresale, endPresale, percent);
    }

    function _transferOperator(address newOperator_) internal ProhibitZeroAddress(newOperator_) {
        address prevOperator = _operatorAddress;
        _operatorAddress = newOperator_;
        if (_presaledAddress != address(0) && _propertyAddress != address(0)) {
            IPresaled(_presaledAddress).setOperator(newOperator_);
            IProperty(_propertyAddress).setOperator(newOperator_);
        }
        emit OperatorTransfered(prevOperator, newOperator_);
    }

    function _transferTrustee(address newTrustee_) internal ProhibitZeroAddress(newTrustee_) {
        address prevTrustee = _trusteeAddress;
        _trusteeAddress = newTrustee_;
        emit TrusteeTransferred(prevTrustee, newTrustee_);
    }

    function _transferProjectOwner(address newOwner_) internal ProhibitZeroAddress(newOwner_) {
        address prevOwner = _projectOwner;
        _projectOwner = newOwner_;
        emit ProjectOwnerTransferred(prevOwner, newOwner_);
    }

    function _initialData(
        uint256 count_,
        uint256 underwriteCount_,
        address tokenAddress_,
        address propertyAddress_,
        address presaledAddress_
    ) internal {
        require(count_ > 0, "PROJECT: COUNT_ZERO");
        require(tokenAddress_ != address(0), "PROJECT: ADDRESS_ZERO");
        count = count_;
        countReserve = count_;
        _underwriteCount = underwriteCount_;
        tokenAddress = tokenAddress_;
        _propertyAddress = propertyAddress_;
        _presaledAddress = presaledAddress_;
        emit InitialData(count_, underwriteCount_, tokenAddress_, propertyAddress_, presaledAddress_);
    }

    function checkOnlyProjectOwner() internal view {
        require(msg.sender == _projectOwner, "PROJECT: NOT_PROJECT_OWNER");
    }

    function _checkOnlyOperator() internal view {
        require(msg.sender == _operatorAddress || msg.sender == owner(), "PROJECT: NOT_OPERATOR");
    }

    function _checkSpvAndTrustee() internal view {
        require(msg.sender == _operatorAddress || msg.sender == _trusteeAddress, "PROJECT: ONLY_SPV_AND_TRUSTEE");
    }

    function _checkIsFullReserve() internal view {
        require(_underwriteCount >= countReserve, "PROJECT: NOT_FULL");
    }

    function _checkIsLeftReserve() internal view {
        require(countReserve > 0, "PROJECT: FULL_RESERVE");
    }

    function _checkIsAvailable() internal view {
        uint256 timestamp = block.timestamp;
        require(timestamp >= startPresale && timestamp <= endPresale, "PROJECT: UNAVAILABLE");
    }

    function _checkProhibitZeroAddress(address caller) internal pure {
        require(caller != address(0), "PROJECT: ADDRESS_0");
    }

    function _checkAvailableNFT(uint256[] memory nftList_) internal view {
        for (uint256 i = 0; i < nftList_.length; i++) {
            for (uint256 j = 0; j < unavailableNFT.length; j++) {
                bool isAvailableNFT = false;
                if (nftList_[i] != unavailableNFT[j]) {
                    isAvailableNFT = true;
                }
                require(isAvailableNFT == true, "PROJECT: UNAVAILABLE_NFT_ID");
            }
        }
    }

    function _pickupAvailableNFT(uint256[] memory nftList_, address member_) internal {
        for (uint256 i = 0; i < nftList_.length; i++) {
            unavailableNFT.push(nftList_[i]);
            getMemberedNFTList[member_].push(nftList_[i]);
        }
    }
}
