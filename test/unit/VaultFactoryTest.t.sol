// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DeployVault} from "../../script/DeployVault.s.sol";
import {VaultFactory} from "../../src/VaultFactory.sol";
import {MockRejecter} from "../mocks/MockRejecter.sol";

contract VaultFactoryTest is Test {
    VaultFactory vaultFactory;

    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant CREATION_FEE = 1000000000000000;
    uint256 constant MINIMUM_FEE = 0.01 ether;

    uint256 constant MAXIMUM_FEE = 100 ether;
    uint256 constant VALID_FUND = 4 ether;
    uint256 constant BASE_LINK_AMOUNT = 4;

    uint256 constant MIN_RELEASE_DAYS = 11;
    uint256 constant MAX_RELEASE_DAYS = 3650;
    uint256 constant VALID_DURATION = 365;

    uint256 constant MIN_NUMBER_OF_BENEFICIAY = 1;
    uint256 constant MAX_NUMBER_OF_BENEFICIAY = 9;

    address CREATOR = makeAddr("CREATOR");
    address USER1 = makeAddr("USER1");
    address USER2 = makeAddr("USER2");
    address USER3 = makeAddr("USER3");

    address[] beneficiaries;

    address[] beneficiarieslst;

    function setUp() external {
        DeployVault deployVault = new DeployVault();

        vaultFactory = deployVault.run();

        console.log("=============================", address(vaultFactory));

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

    /******************************************************************************
     *                        Revert: when no creation fee                        *
     ******************************************************************************/

    function test_CreateVault_RevertsWithoutCreationFee()
        public
        isCreator
        addBeneficiary
    {
        vm.expectRevert(
            VaultFactory.VaultFactory__InsuffcientCreationFee.selector
        );

        vaultFactory.createVault{value: 0}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            beneficiaries
        );
    }

    /******************************************************************************
     *                        Revert: when amount is invalid (amount = 0)                    *
     ******************************************************************************/

    function test_CreateVault_RevertZeroValueAmount()
        public
        isCreator
        addBeneficiary
    {
        vm.expectRevert(VaultFactory.VaultFactory__ZeroValueAmount.selector);

        vaultFactory.createVault{value: CREATION_FEE}(
            0,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            beneficiaries
        );
    }

    /******************************************************************************
     *                        Revert: when amount is less than mininmu                       *
     ******************************************************************************/

    function test_CreateVault_RevertsWhenAmountIsLessThanMinimumEth()
        public
        isCreator
        addBeneficiary
    {
        vm.expectRevert(VaultFactory.VaultFactory__LessThanMinimumEth.selector);

        vaultFactory.createVault{value: CREATION_FEE}(
            0.001 ether,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            beneficiaries
        );
    }

    /******************************************************************************
     *                        Revert: when release time in days is invalid                        *
     ******************************************************************************/

    function test_CreateVault_RevertsWhenReleaseTimeIsInvalid()
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
            BASE_LINK_AMOUNT,
            invalidReleaseTime,
            beneficiaries
        );
    }

    /******************************************************************************
     *                        Revert: when release time in days is too close (0-10 days)                        *
     ******************************************************************************/

    function test_CreateVault_RevertsWhenReleaseTimeTooClose()
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
            BASE_LINK_AMOUNT,
            earlyReleaseTime,
            beneficiaries
        );
    }

    /******************************************************************************
     *                        Revert: when there is no beneficiary                        *
     ******************************************************************************/

    function test_CreateVault_RevertsWhenThereIsNoBeneficiary()
        public
        isCreator
    {
        address[] memory _beneficiaries;

        vm.expectRevert(VaultFactory.VaultFactory__NoBeneficiaryAdded.selector);

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            _beneficiaries
        );
    }

    /******************************************************************************
     *                        Revert: too many beneficiaries (>= 10)                        *
     ******************************************************************************/

    function test_CreateVault_RevertsWhenThereIsTooManyBeneficiaries()
        public
        isCreator
    {
        for (uint256 i = 0; i < 10; i++) {
            address user = vm.addr(i + 1);

            beneficiarieslst.push(user);
        }
        console.log("----------------------", beneficiarieslst.length);

        vm.expectRevert(
            VaultFactory.VaultFactory__BeneficiaryMaxAmountReached.selector
        );

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            beneficiarieslst
        );

        delete beneficiarieslst; //reset the array in storage
    }

    /******************************************************************************
     *                        Revert: duplicate beneficiary                       *
     ******************************************************************************/

    function test_CreateVault_RevertsDuplicateBeneficiary() public isCreator {
        beneficiarieslst.push(USER1);
        beneficiarieslst.push(USER2);
        beneficiarieslst.push(USER1);

        console.log("----------------------", beneficiarieslst.length);

        vm.expectRevert(
            VaultFactory.VaultFactory__DuplicateBeneficiaryAdded.selector
        );

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            beneficiarieslst
        );
        delete beneficiarieslst;
    }

    /******************************************************************************
     *                        Revert: zero address beneficiary                       *
     ******************************************************************************/

    function test_CreateVault_RevertZeroAddressBeneficiary() public isCreator {
        beneficiarieslst.push(address(0));

        vm.expectRevert(
            VaultFactory.VaultFactory__ZeroAddressBeneficiary.selector
        );

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            beneficiarieslst
        );
        delete beneficiarieslst;
    }

    /******************************************************************************
     *                        Benrficiary added sucessfully                       *
     ******************************************************************************/

    function test_CreateVault_BeneficiaryAdded() public isCreator {
        beneficiarieslst.push(USER1);

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            beneficiarieslst
        );

        assertTrue(vaultFactory.isUserBeneficiary(USER1));

        delete beneficiarieslst;
    }

    /******************************************************************************
     *                        test if invalid beneficiary is added                      *
     ******************************************************************************/

    function test_CreateVault_IsUserBeneficiary() public isCreator {
        beneficiarieslst.push(USER1);

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            beneficiarieslst
        );

        assertFalse(vaultFactory.isUserBeneficiary(USER2));

        delete beneficiarieslst;
    }

    /******************************************************************************
     *                               Happy Paths                                   *
     ******************************************************************************/

    /******************************************************************************
     *                        test if vault was created successfully                      *
     ******************************************************************************/

    function test_CreateVault_Successfully() public isCreator addBeneficiary {
        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            beneficiaries
        );

        assertEq(vaultFactory.getVaultCount(), 1);

        address vaultAddress = vaultFactory.getVaultAddress(0);

        assertTrue(vaultAddress != address(0));
        assertTrue(vaultFactory.isValidVault(vaultAddress));
    }

    /******************************************************************************
     *                        test if create vault emit events                     *
     ******************************************************************************/

    function test_CreateVault_EmitEventSuccessfully()
        public
        isCreator
        addBeneficiary
    {
        vm.expectEmit(true, false, false, true);

        emit VaultFactory.CreatedVault(CREATOR, VALID_FUND, 1);

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            beneficiaries
        );
    }

    /******************************************************************************
     *                        test if vault info are saved correctly                      *
     ******************************************************************************/

    function test_CreateVault_SavesVaultInfoCorrectly()
        public
        isCreator
        addBeneficiary
    {
        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            beneficiaries
        );

        VaultFactory.VaultInfo memory _vaultInfo = vaultFactory.getVault(0);

        assertTrue(_vaultInfo.vaultAddress != address(0));
        assertTrue(_vaultInfo.creatorAddress == CREATOR);

        assertEq(_vaultInfo.amount, VALID_FUND);
        assertTrue(_vaultInfo.isActive);
        assertTrue(_vaultInfo.releaseTime > block.timestamp);
    }

    /******************************************************************************
     *                        test create multiple vault                           *
     ******************************************************************************/

    function test_CreateMutipleVault() public isCreator {
        uint256 vaultCount = 3;

        address[] memory _beneficiaries = new address[](1);

        for (uint256 i = 0; i < vaultCount; i++) {
            address user = vm.addr(i + 1);

            _beneficiaries[0] = user;

            vaultFactory.createVault{value: CREATION_FEE}(
                VALID_FUND,
                BASE_LINK_AMOUNT,
                VALID_DURATION,
                _beneficiaries
            );
        }

        assertEq(vaultFactory.getVaultCount(), vaultCount);
        assertEq(
            vaultFactory.getVaultAddress(0) != vaultFactory.getVaultAddress(1),
            true
        );
    }

    /******************************************************************************
     *                        refund excess creation fee                           *
     ******************************************************************************/

    function test_CreateVault_RefundExcessFees()
        public
        isCreator
        addBeneficiary
    {
        uint256 excessFee = 1000000000000000;
        uint256 initialBalance = CREATOR.balance;

        vaultFactory.createVault{value: CREATION_FEE + excessFee}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            beneficiaries
        );

        uint256 balanceAfter = CREATOR.balance;

        assertEq(initialBalance - balanceAfter, CREATION_FEE);
    }

    /******************************************************************************
     *                       revert: refund of creation fee fail                      *
     ******************************************************************************/
    /**@dev refund fail when caller cannot receive the excess creation fee */

    function test_CreateVault_RefundFailWhenCallerCannotReceiveEth() public {
        uint256 excessFee = 10000000000000000;

        address[] memory _beneficiaries = new address[](1);
        address user = vm.addr(1);
        _beneficiaries[0] = user;

        MockRejecter rejecter = new MockRejecter();

        vm.deal(address(rejecter), STARTING_BALANCE);

        vm.prank(address(rejecter));
        vm.expectRevert("Refund failed");

        rejecter.rejectExcess(
            vaultFactory,
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            _beneficiaries,
            CREATION_FEE + excessFee
        );
    }

    /******************************************************************************
     *                            test view functions                             *
     ******************************************************************************/

    function test_VaultisFactory() public isCreator addBeneficiary {
        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            beneficiaries
        );

        address vaultAddress = vaultFactory.getVaultAddress(0);

        assertTrue(
            vaultFactory.getFactoryOf(vaultAddress) == address(vaultFactory)
        );
    }

    /******************************************************************************
     *                                fuzz testing                                *
     ******************************************************************************/

    /******************************************************************************
     *                         Success Path fuzz testing                          *
     ******************************************************************************/

    /**@dev All inputs are valid; vault must be created successfully */

    function testFuzz_CreateVault(
        uint256 amountInWei,
        uint256 releaseTimeDays,
        uint256 numBeneficiaries
    ) public isCreator {
        amountInWei = bound(amountInWei, MINIMUM_FEE, MAXIMUM_FEE);

        releaseTimeDays = bound(
            releaseTimeDays,
            MIN_RELEASE_DAYS,
            MAX_RELEASE_DAYS
        );

        numBeneficiaries = bound(
            numBeneficiaries,
            MIN_NUMBER_OF_BENEFICIAY,
            MAX_NUMBER_OF_BENEFICIAY
        );

        address[] memory beneficiary = _createNthBeneficiary(numBeneficiaries);

        (address vaultAddress, ) = vaultFactory.createVault{
            value: CREATION_FEE
        }(amountInWei, BASE_LINK_AMOUNT, releaseTimeDays, beneficiary);

        assertTrue(vaultAddress != address(0));
        assertTrue(vaultFactory.isValidVault(vaultAddress));
    }

    /******************************************************************************
     *                         exact fee — no refund sent                         *
     ******************************************************************************/

    function testFuzz_CreateVault_NonRefundOnExactFee(
        uint256 releaseTimeDays
    ) public isCreator {
        releaseTimeDays = bound(
            releaseTimeDays,
            MIN_RELEASE_DAYS,
            MAX_RELEASE_DAYS
        );

        address[] memory _beneficiary = _createNthBeneficiary(4);
        uint256 balanceBefore = CREATOR.balance;

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            releaseTimeDays,
            _beneficiary
        );

        assertEq(CREATOR.balance, balanceBefore - CREATION_FEE);
    }

    /******************************************************************************
     *                       vault counter increments by 1                        *
     ******************************************************************************/

    function testFuzz_CreateVault_CounterIncrement(
        uint256 amountInWei,
        uint256 releaseTimeDays,
        uint256 numBeneficiaries
    ) public isCreator {
        amountInWei = bound(amountInWei, MINIMUM_FEE, MAXIMUM_FEE);

        releaseTimeDays = bound(
            releaseTimeDays,
            MIN_RELEASE_DAYS,
            MAX_RELEASE_DAYS
        );

        numBeneficiaries = bound(
            numBeneficiaries,
            MIN_NUMBER_OF_BENEFICIAY,
            MAX_NUMBER_OF_BENEFICIAY
        );

        address[] memory beneficiary = _createNthBeneficiary(numBeneficiaries);

        uint256 counterBefore = vaultFactory.getVaultCount();

        vaultFactory.createVault{value: CREATION_FEE}(
            amountInWei,
            BASE_LINK_AMOUNT,
            releaseTimeDays,
            beneficiary
        );

        assertEq(vaultFactory.getVaultCount(), counterBefore + 1);
    }

    /******************************************************************************
     *                               Invalid paths                                *
     ******************************************************************************/

    /******************************************************************************
     *                     revert: insufficient creation fee                      *
     ******************************************************************************/

    function testFuzz_CreateVault_RevertWhenInsuffcientCreationFee(
        uint256 creationFee
    ) public isCreator {
        creationFee = bound(creationFee, 0, CREATION_FEE - 1);

        address[] memory _beneficiary = _createNthBeneficiary(1);

        vm.expectRevert(
            VaultFactory.VaultFactory__InsuffcientCreationFee.selector
        );
        vaultFactory.createVault{value: creationFee}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            _beneficiary
        );
    }

    /******************************************************************************
     *                        revert: amount below minimum                        *
     ******************************************************************************/

    function testFuzz_CreateVault_RevertBelowMinimumAmount(
        uint256 amountInWei
    ) public isCreator {
        amountInWei = bound(amountInWei, 1, MINIMUM_FEE - 1);

        address[] memory _beneficiary = _createNthBeneficiary(1);

        vm.expectRevert(VaultFactory.VaultFactory__LessThanMinimumEth.selector);

        vaultFactory.createVault{value: CREATION_FEE}(
            amountInWei,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            _beneficiary
        );
    }

    /******************************************************************************
     *                 revert: release time too early (1–10 days)                  *
     ******************************************************************************/

    function testFuzz_CreateVault_RevertWhenEarlyReleaseTime(
        uint256 releaseTimeDays
    ) public isCreator {
        releaseTimeDays = bound(releaseTimeDays, 1, 10);

        address[] memory _beneficiary = _createNthBeneficiary(1);

        vm.expectRevert(
            VaultFactory.VaultFactory__RealeaseTimeTooEarly.selector
        );

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            releaseTimeDays,
            _beneficiary
        );
    }

    /******************************************************************************
     *                   revert: too many beneficiaries (>= 10)                   *
     ******************************************************************************/

    function testFuzz_CreateVault_RevertTooManyBeneficiaries(
        uint256 numBeneficiaries
    ) public isCreator {
        numBeneficiaries = bound(numBeneficiaries, 10, 20);

        address[] memory _beneficiary = _createNthBeneficiary(numBeneficiaries);

        vm.expectRevert(
            VaultFactory.VaultFactory__BeneficiaryMaxAmountReached.selector
        );

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            _beneficiary
        );
    }

    /******************************************************************************
     *                      revert: zero address beneficiary                      *
     ******************************************************************************/

    function testFuzz_CreateVault_RevertsZeroAddressBeneficiaries(
        uint256 zeroIndex
    ) public isCreator {
        zeroIndex = bound(zeroIndex, 0, 2); //inject zero addr at index 0–2

        address[] memory _beneficiary = _createNthBeneficiary(4);
        _beneficiary[zeroIndex] = address(0); //poison 1 slot

        vm.expectRevert(
            VaultFactory.VaultFactory__ZeroAddressBeneficiary.selector
        );

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            _beneficiary
        );
    }

    /******************************************************************************
     *                        revert: duplicate beneficiary                        *
     ******************************************************************************/

    function testFuzz_CreateVault_RevertWhenDupplicateBeneficiary(
        address duplicate
    ) public isCreator {
        vm.assume(duplicate != address(0));
        address[] memory _beneficiary = _createNthBeneficiary(4);

        _beneficiary[0] = duplicate;
        _beneficiary[2] = duplicate;

        vm.expectRevert(
            VaultFactory.VaultFactory__DuplicateBeneficiaryAdded.selector
        );

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            _beneficiary
        );
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

    function test_registerAndPredictIDReturnId() public isCreator {
        address[] memory _beneficiary = _createNthBeneficiary(4);
        (, uint256 upkeepID) = vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            BASE_LINK_AMOUNT,
            VALID_DURATION,
            _beneficiary
        );

        assertGt(upkeepID, 0);
    }
}
