// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;
import {VaultFactory} from "../../src/VaultFactory.sol";
import {Vault} from "../../src/Vault.sol";
import {MockLinkToken} from "./MockLinkToken.sol";

contract MockRejecter {
    bool public rejectEth;
    MockLinkToken linkToken;

    constructor(address _address) {
        linkToken = MockLinkToken(_address);
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
        linkToken.approve(address(vaultFactory), linkAmount);
        vaultFactory.depositLinkToken(linkAmount);
        rejectEth = true;

        vaultFactory.createVault{value: fees}(
            amountInWei,
            linkAmount,
            releaseTime,
            beneficiaries
        );
    }
}

contract RejectVaultWithdrawal {
    bool private rejectEth;

    receive() external payable {
        if (rejectEth) revert("I reject Eth");
    }

    function rejectVaultWithdrawal(Vault vault) external {
        rejectEth = true;
        vault.withdraw();
    }
}
