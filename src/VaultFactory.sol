// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;
import {UnitConverter} from "./libary/UnitConverter.sol";
import {Vault} from "./Vault.sol";

/**
 * @title Trust Fund Vault Factory
 * @author Oscar Onyenacho
 * @notice A factory contract for managing and deploying Vault Contract.
 * @dev    Vault are deployed as individual `Vault` contracts, A creation fee is required
 *         releaseTime are exressed in days
 */
contract VaultFactory {
    /******************************************************************************
     *                              Struct                                         *
     ******************************************************************************/

    struct VaultInfo {
        address vaultAddress;
        address creatorAddress;
        uint256 amount;
        bool isActive;
        uint256 releaseTime;
    }

    /******************************************************************************
     *                              State Variables                               *
     ******************************************************************************/
    uint256 private constant CREATION_FEE = 1000000000000000; // 0.001 eth
    uint256 private svaultCounter;
    uint256 private sminimumEth = 10000000000000000; // 0.01 eth

    mapping(address => bool) private isBeneficiaries;
    mapping(uint256 => VaultInfo) private sVaultInfo;
    mapping(address => bool) private sIsVault;
    mapping(address => address) private sIsFactory;

    /******************************************************************************
     *                                   Errors                                   *
     ******************************************************************************/

    error VaultFactory__InsuffcientCreationFee();
    error VaultFactory__LessThanMinimumEth();
    error VaultFactory__ZeroValueAmount();
    error VaultFactory__RealeaseTimeTooEarly();
    error VaultFactory__InvalidRealeaseTime();
    error VaultFactory__NoBeneficiaryAdded();
    error VaultFactory__ZeroAddressBeneficiary();
    error VaultFactory__BeneficiaryMaxAmountReached();
    error VaultFactory__DuplicateBeneficiaryAdded();

    /******************************************************************************
     *                                   Events                                   *
     ******************************************************************************/

    event CreatedVault(
        address indexed creator,
        uint256 amount,
        uint256 counter
    );

    /******************************************************************************
     *                             External Functions                             *
     ******************************************************************************/

    function createVault(
        uint256 amountInWei,
        uint256 releaseTime,
        address[] calldata beneficiaries
    ) external payable returns (address) {
        address sender = msg.sender;
        uint256 value = msg.value;

        // uint256 amountInWei = UnitConverter.ethToWeiConverter(amount);
        uint256 _releaseTime = releaseTime * 1 days;

        if (value < CREATION_FEE) revert VaultFactory__InsuffcientCreationFee();
        if (amountInWei == 0) revert VaultFactory__ZeroValueAmount();
        if (amountInWei < sminimumEth)
            revert VaultFactory__LessThanMinimumEth();

        if (_releaseTime == 0) revert VaultFactory__InvalidRealeaseTime();
        if (_releaseTime <= 10 days)
            revert VaultFactory__RealeaseTimeTooEarly();

        if (beneficiaries.length < 0) revert VaultFactory__NoBeneficiaryAdded();
        if (beneficiaries.length >= 10)
            revert VaultFactory__BeneficiaryMaxAmountReached();

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address user = beneficiaries[i];
            if (user == address(0))
                revert VaultFactory__ZeroAddressBeneficiary();
            if (isBeneficiaries[user])
                revert VaultFactory__DuplicateBeneficiaryAdded();
            isBeneficiaries[user] = true;
        }

        Vault _vault = new Vault(
            sender,
            amountInWei,
            block.timestamp + _releaseTime,
            beneficiaries
        );

        address _vaultAddr = address(_vault);

        sVaultInfo[svaultCounter] = VaultInfo({
            vaultAddress: _vaultAddr,
            creatorAddress: sender,
            amount: amountInWei,
            isActive: true,
            releaseTime: block.timestamp + _releaseTime
        });

        sIsVault[_vaultAddr] = true;
        sIsFactory[_vaultAddr] = address(this);

        svaultCounter++;

        emit CreatedVault(sender, amountInWei, svaultCounter);

        //refund any eth sent above sminimumEth

        if (value > CREATION_FEE) {
            uint256 refund = value - CREATION_FEE;
            (bool sucess, ) = payable(sender).call{value: refund}("");
            require(sucess, "Refund failed");
        }

        return _vaultAddr;
    }
}
