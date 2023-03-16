// SPDX-License-Identifier: MIT
pragma solidity  0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IXtatuzProject.sol";
import "../interfaces/IXtatuzRouter.sol";

contract XtatuzReferral is Ownable {
    using SafeERC20 for IERC20;

    mapping(uint256 => uint256) private _referralAmount; // Project ID => Amount
    mapping(string => uint256[]) public projectIdsByReferral;
    mapping(string => address) public addressByReferral;
    mapping(address => string) public referralByAddress;
    mapping(string => mapping(uint256 => uint256)) public buyerAgentAmount; // referral -> project id -> amount
    mapping(uint256 => mapping(string => uint256)) public referralLevel; // Project ID => referral code => level
    mapping(string => mapping(uint256 => uint256)) public buyerAgentDepositLeft;

    mapping(uint256 => uint256) public levelsPercentage;

    address public _operatorAddress;
    address public tokenAddress;
    uint256 public constant MAX_PERCENTAGE = 5;
    uint256 public maxPercentage = 5;
    uint256 public defaultPercentage = 3;

    constructor(address tokenAddress_, uint256[] memory initialPercentage_) {
        _transferOperator(tx.origin);
        require(tokenAddress_ != address(0), "REFERRAL: ADDRESS_ZERO");
        tokenAddress = tokenAddress_;
        setReferralLevels(initialPercentage_);
    }

    event OperatorTransfered(address indexed prevOperator, address indexed newSpv);
    event GenerateReferral(address indexed agentAddress, string referral);
    event ChangeDefaultPercent(uint256 prevPercent, uint256 newPercent);
    event ChangeMaxPercent(uint256 prevPercent, uint256 newPercent);
    event IncreaseBuyerRef(uint256 indexed projectId, uint256 referralAmount);
    event SetReferralLevels(uint256[] preLevels, uint256[] newLevels);
    event SetLevel(uint256 indexed projectId, string referral, uint256 level);
    event UpdateReferralAmount(uint256 indexed projectId, uint256 amount_);
    event Claim(uint256 indexed projectId_, string referral_, uint256 amount);
    event WithdrawFundsLeft(string referral_, uint256 indexed projectId_, uint256 amount);

    modifier onlyOperator() {
        _checkOnlyOperator();
        _;
    }

    function generateReferral(address agentAddress_, string memory referral_) public onlyOperator {
        address prevAddress = addressByReferral[referral_];
        require(prevAddress == address(0), "REFERRAL: ALREADY_GENERATE");

        addressByReferral[referral_] = agentAddress_;
        referralByAddress[agentAddress_] = referral_;

        emit GenerateReferral(agentAddress_, referral_);
    }

    function updateReferralAmount(uint256 projectId_, uint256 amount_) public onlyOperator {
        _referralAmount[projectId_] += amount_;
        emit UpdateReferralAmount(projectId_, amount_);
    }

    function getRefferralAmount(uint256 projectId_) public view returns (uint256) {
        return _referralAmount[projectId_];
    }

    function getProjectIdsByReferral(string memory referral_) public view returns (uint256[] memory) {
        return projectIdsByReferral[referral_];
    }

    function increaseBuyerRef(
        uint256 projectId_,
        string memory referral_,
        uint256 amount_
    ) public onlyOperator {
        address agentWallet = addressByReferral[referral_];
        require(agentWallet != address(0), "REFERRAL: INVALID_REFERRAL");
        uint256 level = referralLevel[projectId_][referral_];
        uint256 percentage = defaultPercentage;

        if (level != 0) {
            percentage = levelsPercentage[level];
        }

        uint256 referralAmount = (amount_ * percentage) / 100;
        uint256 totalDeposit = (amount_ * 5) / 100;

        uint256[] memory projectIdList = projectIdsByReferral[referral_];

        bool foundedIndex;
        for (uint256 index = 0; index < projectIdList.length; index++) {
            if (projectIdList[index] == projectId_) {
                foundedIndex = true;
            }
        }
        if (!foundedIndex) {
            projectIdsByReferral[referral_].push(projectId_);
        }

        buyerAgentAmount[referral_][projectId_] += referralAmount;
        buyerAgentDepositLeft[referral_][projectId_] += (totalDeposit - referralAmount);
        updateReferralAmount(projectId_, referralAmount);
        emit IncreaseBuyerRef(projectId_, referralAmount);
    }

    function claim(string memory referral_, uint256 projectId_) public {
        address agent = addressByReferral[referral_];
        address projectAddress = IXtatuzRouter(owner()).getProjectAddressById(projectId_);
        require(projectAddress != address(0), "REFERRAL: INVALID_PROJECT_ID");

        IXtatuzProject.Status status = IXtatuzProject(projectAddress).projectStatus();
        require(status == IXtatuzProject.Status.FINISH, "REFERRAL: PROJECT_NOT_FINISH");
        require(msg.sender == agent, "REFERRAL: INVALID_ACCOUNT");

        uint256 amount = buyerAgentAmount[referral_][projectId_];
        buyerAgentAmount[referral_][projectId_] = 0;

        IERC20(tokenAddress).safeTransfer(msg.sender, amount);
        emit Claim(projectId_, referral_, amount);
    }

    function setDefaultPercentage(uint256 default_) public onlyOperator {
        require(default_ > 0 && default_ <= maxPercentage, "REFERRAL: INVALID_PERCENT");
        uint256 prev = defaultPercentage;
        defaultPercentage = default_;
        emit ChangeDefaultPercent(prev, default_);
    }

    function setMaxPercentage(uint256 max_) public onlyOperator {
        require(max_ > 0 && max_ <= MAX_PERCENTAGE, "REFERRAL: INVALID_PERCENT");
        uint256 prev = maxPercentage;
        maxPercentage = max_;
        emit ChangeMaxPercent(prev, max_);
    }

    function setLevel(
        uint256 projectId_,
        string memory referral_,
        uint256 level_
    ) public onlyOperator {
        require(level_ <= 3, "REFERRAL: MAX_LEVEL_IS_3");
        referralLevel[projectId_][referral_] = level_;
        emit SetLevel(projectId_, referral_, level_);
    }

    function setReferralLevels(uint256[] memory percentagePerLevel_) public onlyOperator {
        uint256[] memory prevLevels = new uint256[](3);
        uint256[] memory newLevels = new uint256[](3);
        require(percentagePerLevel_.length == 3, "REFERRAL: 3_LEVELS");
        require(
            percentagePerLevel_[0] < percentagePerLevel_[1] && percentagePerLevel_[1] < percentagePerLevel_[2],
            "REFERRAL: INVALID_PERCENT_LEVELS"
        );
        for (uint256 i = 0; i < percentagePerLevel_.length; i++) {
            require(percentagePerLevel_[i] > 0 && percentagePerLevel_[i] <= maxPercentage, "REFERRAL: INVALID_PERCENT");
            prevLevels[i] = levelsPercentage[i + 1];
            levelsPercentage[i + 1] = percentagePerLevel_[i];
            newLevels[i] = levelsPercentage[i + 1];
        }
        emit SetReferralLevels(prevLevels, newLevels);
    }

    function withdrawFundsLeft(string memory referral_, uint256 projectId_) external onlyOwner {
        uint256 amount = buyerAgentDepositLeft[referral_][projectId_];
        require(amount > 0, "REFERRAL: NO_LEFT_FUND");
        address projectAddress = IXtatuzRouter(owner()).getProjectAddressById(projectId_);
        require(projectAddress != address(0), "REFERRAL: INVALID_PROJECT_ID");

        IXtatuzProject.Status status = IXtatuzProject(projectAddress).projectStatus();
        require(status == IXtatuzProject.Status.FINISH, "REFERRAL: PROJECT_NOT_FINISH");
        buyerAgentDepositLeft[referral_][projectId_] = 0;
        IERC20(tokenAddress).safeTransfer(msg.sender, amount);
        emit WithdrawFundsLeft(referral_, projectId_, amount);
    }

    function transferOperator(address newOperator_) public onlyOperator {
        _transferOperator(newOperator_);
    }

    function _transferOperator(address newOperator_) internal {
        require(newOperator_ != address(0), "REFERRAL: ADDRESS_0");
        address prevOperator = _operatorAddress;
        _operatorAddress = newOperator_;
        emit OperatorTransfered(prevOperator, newOperator_);
    }

    function _checkOnlyOperator() internal view {
        require(msg.sender == _operatorAddress || msg.sender == owner(), "REFERRAL: NOT_OPERATOR");
    }
}
