// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;
import {Script} from "forge-std/Script.sol";
import {VaultFactory} from "../src/VaultFactory.sol";

contract DeployVault is Script {
    function run() external returns (VaultFactory) {
        vm.startBroadcast();
        VaultFactory vault = new VaultFactory();

        vm.stopBroadcast();
        return vault;
    }
}
