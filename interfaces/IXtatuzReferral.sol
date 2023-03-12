// SPDX-License-Identifier: MIT
pragma solidity  0.8.17;


interface IXtatuzReferral {

    function getProjectIdsByReferral(string memory referral_) external view returns(uint[] memory);

    function addressByReferral(string memory referral) external view returns(address);

    function referralByAddress(address agentAddress_) external view returns(string memory);
    
    function referralLevel(uint256 projectId_, string memory referral) external view returns(uint256);
    
    function levelsPercentage(uint256 level) external view returns(uint256);

    function defaultPercentage() external view returns(uint256);
    
    function buyerAgentAmount(string memory referral, uint256 projectId_) external view returns(uint256);

    function generateReferral(address agentAddress_, string memory referral_) external;

    function updateReferralAmount(uint256 projectId_, uint256 amount_) external;

    function getRefferralAmount(uint256 projectId_) external returns(uint256);

    function increaseBuyerRef(uint256 projectId, string memory referral_, uint256 referralAmount_) external;

    function claim(string memory referral_, uint projectId_) external;

    function setDefaultPercentage(uint256 default_) external;

    function setLevel(uint projectId_, string memory referral_, uint level_) external;

    function setReferralLevels(uint256[] memory percentagePerLevel_) external;
}
