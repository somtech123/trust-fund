// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

contract Vault {
    uint256 amount;
    uint256 releaseTime;
    address[] beneficiaries;
    address owner;

    constructor(
        address _owner,
        uint256 _amount,
        uint256 _releaseTime,
        address[] memory _beneficiaries
    ) {
        owner = _owner;
        amount = _amount;
        releaseTime = _releaseTime;
        beneficiaries = _beneficiaries;
    }
}
