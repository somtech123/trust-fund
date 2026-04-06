// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;
import {Script, console} from "forge-std/Script.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {FundSubscription} from "./Interaction.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployVault is Script {
    function run() external returns (VaultFactory) {
        vm.startBroadcast();
        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        //FundSubscription _fund = new FundSubscription();

        VaultFactory vault = new VaultFactory(
            config.linkAddress,
            config.upKeepRegistraddress
        );

        // _fund.fundContract(config.linkAddress, address(vault));

        vm.stopBroadcast();
        return vault;
    }
}
