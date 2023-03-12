// SPDX-License-Identifier: MIT
pragma solidity  0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IProperty.sol";
import "../interfaces/IXtatuzFactory.sol";
import "../interfaces/IXtatuzRouter.sol";

contract XtatuzReroll is Ownable {
    IXtatuzFactory _xtatusFactory;

    mapping(uint256 => string[]) public rerollData;
    uint256 public rerollFee = 10 * (10 ** 18);
    uint256 private _totalFee;
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
    }

    function setFee(uint256 fee_) public onlyOperator {
        rerollFee = fee_;
    }

    function getRerollData(uint256 projectId_) public view returns (string[] memory) {
        return rerollData[projectId_];
    }
}
