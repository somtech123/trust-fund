// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DeployVault} from "../../script/DeployVault.s.sol";
import {VaultFactory} from "../../src/VaultFactory.sol";
import {Vault} from "../../src/Vault.sol";

import {MockLinkToken} from "../mocks/MockLinkToken.sol";

contract VaultFlowTest is Test {
    VaultFactory vaultFactory;
    Vault vault;
    MockLinkToken linkToken;

    address CREATOR = makeAddr("CREATOR");
    address USER1 = makeAddr("USER1");
    address USER2 = makeAddr("USER2");

    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant MINIMUM_LINK = 2000000000000000000;
    uint256 constant BASE_LINK_AMOUNT = 2000000000000000000;
    uint256 constant CREATION_FEE = 1000000000000000;
    uint256 constant VALID_FUND = 4 ether;
    uint256 constant VALID_DURATION = 365;

    address[] beneficiaries;

    function setUp() external {
        DeployVault deployVault = new DeployVault();

        vaultFactory = deployVault.run();

        linkToken = MockLinkToken(vaultFactory.getLinkToken());

        linkToken.mint(CREATOR, STARTING_BALANCE);

        vm.deal(CREATOR, STARTING_BALANCE);
    }

    modifier isCreator() {
        vm.startPrank(CREATOR);
        _;
        vm.stopPrank();
    }

    modifier addBeneficiary() {
        delete beneficiaries; // reset before each use
        beneficiaries.push(USER1);
        beneficiaries.push(USER2);
        _;
    }

    modifier linkApprovedAndDeposited() {
        linkToken.approve(address(vaultFactory), MINIMUM_LINK);
        vaultFactory.depositLinkToken(MINIMUM_LINK);

        _;
    }

    modifier createVault() {
        uint256 valueSent = VALID_FUND + CREATION_FEE;
        vaultFactory.createVault{value: valueSent}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            beneficiaries
        );

        _;
    }

    /******************************************************************************
     *                                    test                                    *
     ******************************************************************************/

    // function test_VaultFlow_CreateVaultWithoutApprovingLink()
    //     public
    //     linkApprovedAndDeposited
    //     createVault
    // {
    //     // uint256 valueSent = VALID_FUND + CREATION_FEE;
    //     // vaultFactory.createVault{value: valueSent}(
    //     //     VALID_FUND,
    //     //     BASE_LINK_AMOUNT,
    //     //     VALID_DURATION,
    //     //     beneficiaries
    //     // );
    // }
}
