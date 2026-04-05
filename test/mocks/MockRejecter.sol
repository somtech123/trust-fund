// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;
import {VaultFactory} from "../../src/VaultFactory.sol";

contract MockRejecter {
    bool public rejectEth;
    address linkAddress;

    constructor(address _address) {
        linkAddress = _address;
    }

    receive() external payable {
        if (rejectEth) revert("I reject Eth");
    }

    function rejectExcess(
        VaultFactory vaultFactory,
        uint256 amountInWei,
        uint256 linkAmount,
        uint256 releaseTime,
        address[] calldata beneficiaries,
        uint256 fees
    ) external {
        rejectEth = true;
        vaultFactory.createVault{value: fees}(
            amountInWei,
            linkAmount,
            releaseTime,
            beneficiaries
        );
    }
}
