// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;
import {Script, console} from "forge-std/Script.sol";
import {CodeConstants} from "./HelperConfig.s.sol";
import {MockLinkToken} from "@chainlink/contracts/src/v0.8/mocks/MockLinkToken.sol";

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether;

    function fundContract(address linkAddress, address contractAddress) public {
        // MockLinkToken(linkAddress).setBalance(contractAddress, FUND_AMOUNT);
    }
}
