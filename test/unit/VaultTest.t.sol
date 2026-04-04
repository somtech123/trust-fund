// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DeployVault} from "../../script/DeployVault.s.sol";
import {VaultFactory} from "../../src/VaultFactory.sol";
import {Vault} from "../../src/Vault.sol";
import {MockInvalidFactory} from "../mocks/MockFactory.sol";

contract VaultTest is Test {
    VaultFactory vaultFactory;
    Vault vault;

    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant CREATION_FEE = 1000000000000000;
    uint256 constant VALID_FUND = 4 ether;
    uint256 constant VALID_DURATION = 365;
    uint256 constant BASE_LINK_AMOUNT = 4;

    address[] beneficiaries;

    address CREATOR = makeAddr("CREATOR");
    address USER1 = makeAddr("USER1");
    address USER2 = makeAddr("USER2");

    function setUp() external {
        DeployVault deployVault = new DeployVault();

        vaultFactory = deployVault.run();

        vm.deal(CREATOR, STARTING_BALANCE);
        beneficiaries.push(USER1);
        beneficiaries.push(USER2);

        vm.prank(CREATOR);
        address vaultAddress = vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            beneficiaries
        );

        vault = Vault(vaultAddress);
    }

    function test_Vault_CheckOpenVaultState() public view {
        assert(vault.getVaultState() == Vault.VaultState.OPEN);
    }

    function test_Vault_IsFromFactory() public view {
        assertEq(vault.FACTORY_ADDRESS(), address(vaultFactory));
    }

    function test_Vault_ConstructorRevertIfZeroAddressFactory() public {
        address fakeFactory = address(0);

        vm.expectRevert(Vault.Vault__InvalidFactoryAddress.selector);

        new Vault(
            CREATOR,
            fakeFactory,
            VALID_FUND,
            VALID_DURATION,
            beneficiaries
        );
    }

    /******************************************************************************
     *                       Test checkupkeep invalid paths                       *
     ******************************************************************************/

    /******************************************************************************
     *                            test time not passed                            *
     ******************************************************************************/

    function test_CheckUpkeep_ReturnsFalse_WhenTimeNotPassed() public view {
        (bool upkeepNeeded, ) = vault.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    /******************************************************************************
     *                          check if vault is valid                           *
     ******************************************************************************/
    /**@dev Deploy mock factory that returns false for all vaults */

    function test_CheckUpkeep_ReturnsFalse_WhenNotFromFactory() public {
        MockInvalidFactory rogueFactory = new MockInvalidFactory();

        Vault rogueVault = new Vault(
            CREATOR,
            address(rogueFactory),
            VALID_FUND,
            VALID_DURATION,
            beneficiaries
        );

        (bool upkeepNeeded, ) = rogueVault.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    /******************************************************************************
     *                           check if vault is closed                           *
     ******************************************************************************/

    function test_CheckUpkeep_ReturnsFalse_WhenVaultClosed() public {
        vm.warp(block.timestamp + VALID_DURATION + 365 days);
        vm.roll(block.number + 1);

        vault.performUpkeep("");

        (bool upkeepNeeded, ) = vault.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    /******************************************************************************
     *                           upkeep only true when enough time has passed                           *
     ******************************************************************************/

    function testFuzz_CheckUpkeep_TimeCondition(uint256 timeElapsed) public {
        uint256 releaseTime = vault.getReleaseTimeStamp();
        timeElapsed = bound(timeElapsed, releaseTime, releaseTime + 30 days);

        vm.warp(block.timestamp + timeElapsed);

        (bool upkeepNeeded, ) = vault.checkUpkeep("");

        assertTrue(upkeepNeeded);
    }
}
