// SPDX-License-Identifier: MIT
pragma solidity  0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract XtatuzReroll is Ownable {

    mapping(uint256 => string[]) public rerollData;
    uint256 public rerollFee = 10 * (10 ** 18);
    address public _operator;
    address public _routerAddress;

    address public tokenAddress;

    modifier ProhibitZeroAddress(address caller) {
        require(caller != address(0), "REROLL: ADDRESS_0");
        _;
    }

    modifier onlyOperator() {
        require(
            msg.sender == _operator || msg.sender == owner() || msg.sender == _routerAddress,
            "REROLL: NOT_OPERATOR"
        );
        _;
    }

    event SetRerollData(uint256 indexed projectId_, string[] rerollData_);
    event SetFee(uint256 prevFee_, uint256 newFee);

    constructor(
        address operator_,
        address routerAddress_,
        address tokenAddress_
    ) ProhibitZeroAddress(operator_) {
        _operator = operator_;
        _routerAddress = routerAddress_;
        tokenAddress = tokenAddress_;
    }

    function setRerollData(uint256 projectId_, string[] memory rerollData_) public onlyOperator {
        require(rerollData_.length > 0, "REROLL: OUT_OF_DATA");
        rerollData[projectId_] = rerollData_;
        emit SetRerollData(projectId_, rerollData_);
    }

    function setFee(uint256 fee_) public onlyOperator {
        uint256 prevFee = rerollFee;
        rerollFee = fee_;
        emit SetFee(prevFee, fee_);
    }

    function getRerollData(uint256 projectId_) public view returns (string[] memory) {
        return rerollData[projectId_];
    }
}
