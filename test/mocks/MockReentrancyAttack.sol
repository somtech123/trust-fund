// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;
import {Vault} from "../../src/Vault.sol";

contract MockReentrancyAttack {
    bool attacking;
    uint attackCount;
    Vault vault;

    function setVault(address _vault) public {
        vault = Vault(_vault);
    }

    function attack() public {
        attacking = true;
        attackCount = 0;
        vault.withdraw();
    }

    receive() external payable {
        if (attacking && attackCount < 5) {
            attackCount++;
            vault.withdraw();
        }
    }
}
