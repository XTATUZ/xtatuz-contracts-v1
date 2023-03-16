// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./Presaled.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PresaledFactory is Ownable {
    event CreatePresale(string name, address indexed presaleAddress);

    function createPresale(
        string memory _name,
        string memory _symbol,
        uint256 count_,
        bytes32 _salt,
        address operator_,
        address routerAddress_
    ) public onlyOwner returns (address) {
        address presaledAddress = address(new Presaled{salt: _salt}(_name, _symbol, count_, operator_, routerAddress_));
        Presaled(presaledAddress).transferOwnership(msg.sender);
        emit CreatePresale(_name, presaledAddress);
        return presaledAddress;
    }
}
