// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {DeployVault} from "../../script/DeployVault.s.sol";
import {VaultFactory} from "../../src/VaultFactory.sol";

contract VaultFactoryTest is Test {
    VaultFactory vaultFactory;

    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant CREATION_FEE = 1000000000000000;
    uint256 constant MINIMUM_FEE = 0.01 ether;
    uint256 constant VALID_FUND = 4 ether;
    uint256 constant VALID_DURATION = 365;

    address CREATOR = makeAddr("CREATOR");
    address USER1 = makeAddr("USER1");
    address USER2 = makeAddr("USER2");
    address USER3 = makeAddr("USER3");

    address[] beneficiaries;

    function setUp() external {
        DeployVault deployVault = new DeployVault();

        vaultFactory = deployVault.run();

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

    /******************************************************************************
     *                                Invalid path                                *
     ******************************************************************************/

    // test creating vault without creation fee ---------------------------------

    function testCreateVaultWithoutCreationFee()
        public
        isCreator
        addBeneficiary
    {
        vm.expectRevert(
            VaultFactory.VaultFactory__InsuffcientCreationFee.selector
        );

        vaultFactory.createVault{value: 0}(
            VALID_FUND,
            VALID_DURATION,
            beneficiaries
        );
    }

    // test creating vault without vault amount ---------------------------------

    function testCreateVaultWithoutValidAmount()
        public
        isCreator
        addBeneficiary
    {
        vm.expectRevert(VaultFactory.VaultFactory__ZeroValueAmount.selector);

        vaultFactory.createVault{value: CREATION_FEE}(
            0,
            VALID_DURATION,
            beneficiaries
        );
    }

    // test creating vault with less than minimum amount ---------------------------------

    function testCreateVaultWithoutLessThanMinimunAmount()
        public
        isCreator
        addBeneficiary
    {
        vm.expectRevert(VaultFactory.VaultFactory__LessThanMinimumEth.selector);

        vaultFactory.createVault{value: CREATION_FEE}(
            0.001 ether,
            VALID_DURATION,
            beneficiaries
        );
    }

    // test creating vault with invalid release time ---------------------------------

    function testCreateVaultWithInvalidReleaseTime()
        public
        isCreator
        addBeneficiary
    {
        uint256 invalidReleaseTime = 0;
        vm.expectRevert(
            VaultFactory.VaultFactory__InvalidRealeaseTime.selector
        );

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            invalidReleaseTime,
            beneficiaries
        );
    }

    // test creating vault with release time too close ---------------------------------

    function testCreateVaultWithReleaseTimeTooClose()
        public
        isCreator
        addBeneficiary
    {
        uint256 earlyReleaseTime = 9;
        vm.expectRevert(
            VaultFactory.VaultFactory__RealeaseTimeTooEarly.selector
        );

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            earlyReleaseTime,
            beneficiaries
        );
    }
}
