// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DeployVault} from "../../script/DeployVault.s.sol";
import {VaultFactory} from "../../src/VaultFactory.sol";
import {Vault} from "../../src/Vault.sol";
import {MockInvalidFactory} from "../mocks/MockFactory.sol";

import {MockLinkToken, MockLinkTokenReturnsFalse} from "../mocks/MockLinkToken.sol";

contract VaultTest is Test {
    VaultFactory vaultFactory;
    Vault vault;
    MockLinkToken linkToken;

    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant CREATION_FEE = 1000000000000000;
    uint256 constant VALID_FUND = 4 ether;
    uint256 constant VALID_DURATION = 365;
    uint256 constant BASE_LINK_AMOUNT = 2000000000000000000;

    uint256 constant MINIMUM_FEE = 0.01 ether;

    address[] beneficiaries;

    address CREATOR = makeAddr("CREATOR");
    address USER1 = makeAddr("USER1");
    address USER2 = makeAddr("USER2");
    address USER3 = makeAddr("USER3");

    function setUp() external {
        DeployVault deployVault = new DeployVault();

        vaultFactory = deployVault.run();
        linkToken = MockLinkToken(vaultFactory.getLinkToken());

        vm.startPrank(CREATOR);

        linkToken.mint(CREATOR, STARTING_BALANCE);
        linkToken.approve(address(vaultFactory), BASE_LINK_AMOUNT);

        vaultFactory.depositLinkToken(BASE_LINK_AMOUNT);

        vm.deal(CREATOR, STARTING_BALANCE);
        beneficiaries.push(USER1);
        beneficiaries.push(USER2);
        beneficiaries.push(USER3);

        (address vaultAddress, ) = vaultFactory.createVault{
            value: CREATION_FEE + VALID_FUND
        }(VALID_FUND, BASE_LINK_AMOUNT, VALID_DURATION, beneficiaries);

        vm.stopPrank();

        vault = Vault(vaultAddress);
    }

    modifier prepareVaultForUpkeep() {
        uint256 releaseTime = vault.getReleaseTimeStamp();
        vm.warp(block.timestamp + VALID_DURATION + releaseTime);

        vm.roll(block.number + 1);

        _;
    }

    modifier isCreator() {
        vm.startPrank(CREATOR);
        _;
        vm.stopPrank();
    }

    modifier isUser1() {
        vm.startPrank(USER1);
        _;
        vm.stopPrank();
    }

    modifier linkApprovedAndDeposited() {
        linkToken.approve(address(vaultFactory), BASE_LINK_AMOUNT);
        vaultFactory.depositLinkToken(BASE_LINK_AMOUNT);

        _;
    }

    modifier prepareVaultForWithdrawal() {
        uint256 releaseTime = vault.getReleaseTimeStamp();
        vm.warp(block.timestamp + VALID_DURATION + releaseTime);

        vm.roll(block.number + 1);

        vault.performUpkeep("");

        _;
    }

    /******************************************************************************
     *               HELPER: generate N distinct non-zero addresses               *
     ******************************************************************************/
    function _createNthBeneficiary(
        uint256 nLength
    ) internal pure returns (address[] memory arr) {
        arr = new address[](nLength);
        for (uint256 i = 0; i < nLength; i++) {
            arr[i] = vm.addr(i + 1);
        }
        return arr;
    }

    /******************************************************************************
     *                                   tests                                    *
     ******************************************************************************/

    function test_Vault_SetVaultAmount() public view {
        assert(vault.getVaultAmount() == VALID_FUND);
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

        new Vault{value: VALID_FUND}(
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

        Vault rogueVault = new Vault{value: VALID_FUND}(
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

    function test_PerformUpkeep_CloseVault() public prepareVaultForUpkeep {
        vault.performUpkeep("");

        assert(vault.getVaultState() == Vault.VaultState.CLOSE);
    }

    function test_PerformUpKeep_ClearsVaultAmount()
        public
        prepareVaultForUpkeep
    {
        vault.performUpkeep("");

        assertEq(vault.getVaultAmount(), 0);
    }

    function test_PerfrmUpKeep_SetsPendingWithdrawalsCorrectly()
        public
        prepareVaultForUpkeep
    {
        uint amount = VALID_FUND;
        uint beneficiariesLength = beneficiaries.length;
        vault.performUpkeep("");

        uint256 share = amount / beneficiariesLength;
        uint256 remainder = amount % beneficiariesLength;

        for (uint256 i = 0; i < beneficiariesLength - 1; i++) {
            assertEq(vault.getPendingWithdrawal(beneficiaries[i]), share);
        }
        address lastBeneficiary = beneficiaries[beneficiaries.length - 1];

        assertEq(
            vault.getPendingWithdrawal(lastBeneficiary),
            share + remainder
        );
    }

    function test_PerformUpkeep_EmitsEvents() public prepareVaultForUpkeep {
        vm.expectEmit(true, true, false, false);

        emit Vault.Vault__UpKeepPerform(VALID_FUND, beneficiaries.length);

        vault.performUpkeep("");
    }

    /******************************************************************************
     *                                  reverts                                   *
     ******************************************************************************/

    function test_PerformUpKeep_RevertIfUpKeepNeededIsTooEary() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Vault.Vault__InvalidCheckUpKeepData.selector,
                VALID_FUND,
                uint256(Vault.VaultState.OPEN)
            )
        );

        vault.performUpkeep("");
    }

    function test_PerformUpKeep_RevertsIfUpkeepIsClosed()
        public
        prepareVaultForUpkeep
    {
        vault.performUpkeep("");

        vm.expectRevert(
            abi.encodeWithSelector(
                Vault.Vault__InvalidCheckUpKeepData.selector,
                0,
                uint256(Vault.VaultState.CLOSE)
            )
        );

        vault.performUpkeep("");
    }

    /******************************************************************************
     *                                 fuzz test                                  *
     ******************************************************************************/

    function testFuzz_PerformUpkeep_SharesNeverExceedTotal(
        uint256 fundAmount
    ) public isCreator linkApprovedAndDeposited {
        Vault _vault;
        vm.assume(fundAmount > MINIMUM_FEE && fundAmount <= 8 ether);
        vm.deal(CREATOR, CREATION_FEE + fundAmount + 1 ether);

        address[] memory _benefactors = _createNthBeneficiary(7);

        (address vaultAddress, ) = vaultFactory.createVault{
            value: CREATION_FEE + fundAmount
        }(fundAmount, BASE_LINK_AMOUNT, VALID_DURATION, _benefactors);

        _vault = Vault(vaultAddress);

        uint256 releaseTime = vault.getReleaseTimeStamp();
        vm.warp(block.timestamp + VALID_DURATION + releaseTime);

        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = _vault.checkUpkeep("");

        assertTrue(upkeepNeeded);

        _vault.performUpkeep("");

        uint256 totalPending;

        for (uint256 i = 0; i < _benefactors.length; i++) {
            totalPending += _vault.getPendingWithdrawal(_benefactors[i]);
        }

        assertEq(fundAmount, totalPending);
    }

    function test_Withdraw_RevertsIfNotFromFactory() public isUser1 {
        MockInvalidFactory rogueFactory = new MockInvalidFactory();
        vm.deal(USER1, STARTING_BALANCE);

        Vault rogueVault = new Vault{value: VALID_FUND}(
            CREATOR,
            address(rogueFactory),
            VALID_FUND,
            VALID_DURATION,
            beneficiaries
        );

        vm.expectRevert(Vault.Vault__InValidVault.selector);

        rogueVault.withdraw();
    }

    function test_Withdraw_RevertIfCallerNotBeneficiary() public {
        address rogueUser = makeAddr("rogueUser");

        vm.startPrank(rogueUser);
        vm.expectRevert(Vault.Vault__NotBeneficiary.selector);
        vault.withdraw();
        vm.stopPrank();
    }

    function test_Withdraw_RevertsIfNoPendingWithdrawal() public isUser1 {
        vm.expectRevert(Vault.Vault__NoPendingWithdrawal.selector);

        vault.withdraw();
    }

    function test_Withdraw_WithdrawalIsSuccessfull()
        public
        isUser1
        prepareVaultForWithdrawal
    {
        vault.withdraw();
        assertEq(vault.getPendingWithdrawal(USER1), 0);
    }

    function test_Withdraw_EmitEvents()
        public
        isUser1
        prepareVaultForWithdrawal
    {
        uint256 payment = vault.getPendingWithdrawal(USER1);
        vm.expectEmit(true, false, false, true);
        emit Vault.Vault__Withdrawn(USER1, payment);
        vault.withdraw();
    }

    function test_Withdraw_FundsReceived()
        public
        isUser1
        prepareVaultForWithdrawal
    {
        uint256 currentBalance = USER1.balance;
        uint256 payment = vault.getPendingWithdrawal(USER1);

        vault.withdraw();
        uint256 newBalance = payment + currentBalance;

        assertEq(USER1.balance, newBalance);
    }
}
