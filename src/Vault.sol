// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {VaultFactory} from "./VaultFactory.sol";

contract Vault is Ownable, AutomationCompatibleInterface, ReentrancyGuard {
    enum VaultState {
        OPEN,
        CLOSE
    }

    /******************************************************************************
     *                              State Variables                               *
     ******************************************************************************/
    address public immutable FACTORY_ADDRESS;
    uint256 public immutable RELEASE_TIME;

    uint256 private amount;
    uint256 private lastTimeStamp;
    address private creator;
    VaultState private vaultState;

    address[] private beneficiaries;

    mapping(address => uint256) private pendingWithdrawals;

    /******************************************************************************
     *                                   Errors                                   *
     ******************************************************************************/
    error Vault__NotOwner();
    error Vault__InvalidFactoryAddress();
    error Vault__InvalidReleaseTime();
    error Vault__InvalidCheckUpKeepData(uint256 amount, uint256 vaultState);
    error Vault__NoBeneficiaryAdded();
    error Vault__NoPendingWithdrawal();
    error Vault__NotBeneficiary();
    error Vault__InValidVault();
    error Vault__InvalidAmount();

    event Vault__UpKeepPerform(uint256 amount, uint256 beneficiariesLength);
    event Vault__Withdrawn(address indexed sender, uint256 amount);

    constructor(
        address _creator,
        address _factory,
        uint256 _amount,
        uint256 _releaseTime,
        address[] memory _beneficiaries
    ) payable Ownable(_creator) {
        if (msg.value != _amount) revert Vault__InvalidAmount();
        if (_factory == address(0)) revert Vault__InvalidFactoryAddress();
        if (_releaseTime == 0) revert Vault__InvalidReleaseTime();
        if (_beneficiaries.length == 0) revert Vault__NoBeneficiaryAdded();

        creator = msg.sender;
        amount = _amount;
        beneficiaries = _beneficiaries;
        lastTimeStamp = block.timestamp;

        vaultState = VaultState.OPEN;
        RELEASE_TIME = _releaseTime;
        FACTORY_ADDRESS = _factory;
    }

    modifier onlyValidVault() {
        if (!VaultFactory(FACTORY_ADDRESS).isValidVault(address(this)))
            revert Vault__InValidVault();
        _;
    }

    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        if (!VaultFactory(FACTORY_ADDRESS).isValidVault(address(this))) {
            return (false, "");
        }

        bool timePassed = ((block.timestamp - lastTimeStamp) >= RELEASE_TIME);
        bool hasBalance = amount > 0;
        bool isOpen = vaultState == VaultState.OPEN;

        upkeepNeeded = (timePassed && hasBalance && isOpen);
        return (upkeepNeeded, "");
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override nonReentrant {
        uint beneficiariesLength = beneficiaries.length;

        (bool upkeepNeeded, ) = checkUpkeep("");

        if (!upkeepNeeded)
            revert Vault__InvalidCheckUpKeepData(amount, uint256(vaultState));

        vaultState = VaultState.CLOSE;
        uint256 totalAmount = amount;
        amount = 0;

        uint256 share = totalAmount / beneficiariesLength;
        uint256 remainder = totalAmount % beneficiariesLength;

        for (uint256 i = 0; i < beneficiariesLength; i++) {
            uint256 payment = (i == beneficiariesLength - 1)
                ? share + remainder
                : share;

            pendingWithdrawals[beneficiaries[i]] += payment;
        }
        emit Vault__UpKeepPerform(totalAmount, beneficiariesLength);
    }

    function withdraw() public nonReentrant onlyValidVault {
        if (!VaultFactory(FACTORY_ADDRESS).isUserBeneficiary(msg.sender))
            revert Vault__NotBeneficiary();

        uint256 payment = pendingWithdrawals[msg.sender];
        if (payment == 0) revert Vault__NoPendingWithdrawal();

        pendingWithdrawals[msg.sender] = 0;
        emit Vault__Withdrawn(msg.sender, payment);

        (bool success, ) = payable(msg.sender).call{value: payment}("");
        require(success, "Transfer Failed");
    }

    /******************************************************************************
     *                               View Functions                               *
     ******************************************************************************/

    function getVaultState() public view returns (VaultState) {
        return vaultState;
    }

    function getReleaseTimeStamp() public view returns (uint256) {
        return RELEASE_TIME;
    }

    function getVaultAmount() public view returns (uint256) {
        return amount;
    }

    function getPendingWithdrawal(
        address benefactor
    ) public view returns (uint256) {
        return pendingWithdrawals[benefactor];
    }
}
