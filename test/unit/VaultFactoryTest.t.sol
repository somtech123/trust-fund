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
    uint256 constant MIN_FEE = 0.1 ether;
    uint256 constant MAXIMUM_FEE = 100 ether;
    uint256 constant VALID_FUND = 4 ether;

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

    // test creating vault with empty or no beneficiary ---------------------------------

    function testCreateVaultWithEmptyBeneficiary() public isCreator {
        address[] memory _beneficiaries;

        vm.expectRevert(VaultFactory.VaultFactory__NoBeneficiaryAdded.selector);

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            VALID_DURATION,
            _beneficiaries
        );
    }

    // test creating vault with max number of beneficiary  ---------------------------------
    // max beneficiary= 10

    function testCreateVaultWithMoreThanTenBeneficiary() public isCreator {
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
            VALID_DURATION,
            beneficiarieslst
        );

        delete beneficiarieslst; //reset the array in storage
    }

    // test creating vault with duplicate beneficiary ---------------------------------

    function testCreateVaultWithDuplicateBeneficiary() public isCreator {
        beneficiarieslst.push(USER1);
        beneficiarieslst.push(USER2);
        beneficiarieslst.push(USER1);

        console.log("----------------------", beneficiarieslst.length);

        vm.expectRevert(
            VaultFactory.VaultFactory__DuplicateBeneficiaryAdded.selector
        );

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            VALID_DURATION,
            beneficiarieslst
        );
        delete beneficiarieslst;
    }

    // test creating vault with zero address beneficiary---------------------------------

    function testCreateVaultWithZeroAddressBeneficiary() public isCreator {
        beneficiarieslst.push(address(0));

        vm.expectRevert(
            VaultFactory.VaultFactory__ZeroAddressBeneficiary.selector
        );

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            VALID_DURATION,
            beneficiarieslst
        );
        delete beneficiarieslst;
    }

    // test beneficiary is added when creating vault ---------------------------------

    function testCreateVaultBeneficiaryAdded() public isCreator {
        beneficiarieslst.push(USER1);

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            VALID_DURATION,
            beneficiarieslst
        );

        assertTrue(vaultFactory.isUserBeneficiary(USER1));

        delete beneficiarieslst;
    }

    // test is invalid beneficiary is added to vault ---------------------------------

    function testCreateVaultWithInvalidBeneficiary() public isCreator {
        beneficiarieslst.push(USER1);

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            VALID_DURATION,
            beneficiarieslst
        );

        assertFalse(vaultFactory.isUserBeneficiary(USER2));

        delete beneficiarieslst;
    }

    /******************************************************************************
     *                               Success Paths                                *
     ******************************************************************************/

    // test creating vault was successful ---------------------------------

    function testCreateVaultSuccessfully() public isCreator addBeneficiary {
        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            VALID_DURATION,
            beneficiaries
        );

        assertEq(vaultFactory.getVaultCount(), 1);

        address vaultAddress = vaultFactory.getVaultAddress(0);

        assertTrue(vaultAddress != address(0));
        assertTrue(vaultFactory.isValidVault(vaultAddress));
    }

    // test creating vault events are emitted successful ---------------------------------

    function testCreateVaultEmitEventSuccessfully()
        public
        isCreator
        addBeneficiary
    {
        vm.expectEmit(true, false, false, true);

        emit VaultFactory.CreatedVault(CREATOR, VALID_FUND, 1);

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            VALID_DURATION,
            beneficiaries
        );
    }

    // test created vault info are saved correctly ---------------------------------

    function testCreateVaultSavesVaultInfoCorrectly()
        public
        isCreator
        addBeneficiary
    {
        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
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

    // test multiple creation of vault is successfull ---------------------------------

    function testCreateMutipleVault() public isCreator {
        uint256 vaultCount = 3;

        address[] memory _beneficiaries = new address[](1);

        for (uint256 i = 0; i < vaultCount; i++) {
            address user = vm.addr(i + 1);

            _beneficiaries[0] = user;

            vaultFactory.createVault{value: CREATION_FEE}(
                VALID_FUND,
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

    // test created vault refund excess creation fee ---------------------------------

    function testCreateVaultRefundExcessFees() public isCreator addBeneficiary {
        uint256 excessFee = 1000000000000000;
        uint256 initialBalance = CREATOR.balance;

        vaultFactory.createVault{value: CREATION_FEE + excessFee}(
            VALID_FUND,
            VALID_DURATION,
            beneficiaries
        );

        uint256 balanceAfter = CREATOR.balance;

        assertEq(initialBalance - balanceAfter, CREATION_FEE);
    }

    // test refund fail when caller cannot receive the excess creation fee ---------------------------------

    function testCreateVaultRefundFailWhenCallerCannotReceiveEth() public {
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
            VALID_DURATION,
            _beneficiaries,
            CREATION_FEE + excessFee
        );
    }

    /******************************************************************************
     *                            test view functions                             *
     ******************************************************************************/
    // test created vault is from the vaultfactory ---------------------------------

    function testVaultisFactory() public isCreator addBeneficiary {
        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
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

    /**dev All inputs are valid; vault must be created successfully */

    function testFuzzCreateVault(
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

        address vaultAddress = vaultFactory.createVault{value: CREATION_FEE}(
            amountInWei,
            releaseTimeDays,
            beneficiary
        );

        assertTrue(vaultAddress != address(0));
        assertTrue(vaultFactory.isValidVault(vaultAddress));
    }

    /******************************************************************************
     *                         exact fee — no refund sent                         *
     ******************************************************************************/

    function testFuzzNonRefundOnExactFee(
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
            releaseTimeDays,
            _beneficiary
        );

        assertEq(CREATOR.balance, balanceBefore - CREATION_FEE);
    }

    /******************************************************************************
     *                       vault counter increments by 1                        *
     ******************************************************************************/

    function testFuzzCreateVaultCounterIncrement(
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

    function testFuzzCreateVaultWithInsuffcientCreationFee(
        uint256 creationFee
    ) public isCreator {
        creationFee = bound(creationFee, 0, CREATION_FEE - 1);

        address[] memory _beneficiary = _createNthBeneficiary(1);

        vm.expectRevert(
            VaultFactory.VaultFactory__InsuffcientCreationFee.selector
        );
        vaultFactory.createVault{value: creationFee}(
            VALID_FUND,
            VALID_DURATION,
            _beneficiary
        );
    }

    /******************************************************************************
     *                        revert: amount below minimum                        *
     ******************************************************************************/

    function testFuzzCreateVaultWithBelowAmount(
        uint256 amountInWei
    ) public isCreator {
        amountInWei = bound(amountInWei, 1, MINIMUM_FEE - 1);

        address[] memory _beneficiary = _createNthBeneficiary(1);

        vm.expectRevert(VaultFactory.VaultFactory__LessThanMinimumEth.selector);

        vaultFactory.createVault{value: CREATION_FEE}(
            amountInWei,
            VALID_DURATION,
            _beneficiary
        );
    }

    /******************************************************************************
     *                 revert: release time too early (1–10 days)                  *
     ******************************************************************************/

    function testFuzzCreateVaultWithEarlyReleaseTime(
        uint256 releaseTimeDays
    ) public isCreator {
        releaseTimeDays = bound(releaseTimeDays, 1, 10);

        address[] memory _beneficiary = _createNthBeneficiary(1);

        vm.expectRevert(
            VaultFactory.VaultFactory__RealeaseTimeTooEarly.selector
        );

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            releaseTimeDays,
            _beneficiary
        );
    }

    /******************************************************************************
     *                   revert: too many beneficiaries (>= 10)                   *
     ******************************************************************************/

    function testFuzzCreateVaultWithTooManyBeneficiaries(
        uint256 numBeneficiaries
    ) public isCreator {
        numBeneficiaries = bound(numBeneficiaries, 10, 20);

        address[] memory _beneficiary = _createNthBeneficiary(numBeneficiaries);

        vm.expectRevert(
            VaultFactory.VaultFactory__BeneficiaryMaxAmountReached.selector
        );

        vaultFactory.createVault{value: CREATION_FEE}(
            VALID_FUND,
            VALID_DURATION,
            _beneficiary
        );
    }

    /******************************************************************************
     *                      revert: zero address beneficiary                      *
     ******************************************************************************/

    function testFuzzWithZeroAddressBeneficiaries(
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
            VALID_DURATION,
            _beneficiary
        );
    }

    /******************************************************************************
     *                        revert: duplicate beneficiary                        *
     ******************************************************************************/

    function testFuzzCreateVaultWithDupplicateBeneficiary(
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
}
