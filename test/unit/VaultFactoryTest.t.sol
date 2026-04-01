// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {DeployVault} from "../../script/DeployVault.s.sol";

contract VaultFactoryTest is Test {
    VaultFactory vaultFactory;

    function setUp() external {
        DeployVault deployVault = new DeployVault();

        vaultFactory = deployVault.run();
    }
}
