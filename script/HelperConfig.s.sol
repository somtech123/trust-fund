// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;
import {Script} from "forge-std/Script.sol";
import {MockLinkToken} from "../test/mocks/MockLinkToken.sol";
import {MockAutomationRegistrar} from "../test/mocks/MockAutomationRegistrar.sol";

abstract contract CodeConstants {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__InvalidChain();

    struct NetworkConfig {
        address linkAddress;
        address upKeepRegistraddress;
    }

    NetworkConfig public localNetworkConfigs;
    mapping(uint256 chainId => NetworkConfig) networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(
        uint256 chainId
    ) private returns (NetworkConfig memory) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID) {
            return networkConfigs[ETH_SEPOLIA_CHAIN_ID];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChain();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                linkAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                upKeepRegistraddress: 0xb0E49c5D0d05cbc241d68c05BC5BA1d1B7B72976
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // deploy mocks

        MockLinkToken linkToken = new MockLinkToken();
        MockAutomationRegistrar _mockRegistrar = new MockAutomationRegistrar();

        localNetworkConfigs = NetworkConfig({
            linkAddress: address(linkToken),
            upKeepRegistraddress: address(_mockRegistrar)
        });

        return localNetworkConfigs;
    }
}
