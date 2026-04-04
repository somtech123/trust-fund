// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;
import {Script} from "forge-std/Script.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployVault is Script {
    function run() external returns (VaultFactory) {
        vm.startBroadcast();
        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        VaultFactory vault = new VaultFactory(config.linkAddress);

        vm.stopBroadcast();
        return vault;
    }
}
