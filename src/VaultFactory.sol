// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {Vault} from "./Vault.sol";
import {IKeeperRegistrar} from "./interface/IKeeperRegistry.sol";

/**
 * @title Trust Fund Vault Factory
 * @author Oscar Onyenacho
 * @notice A factory contract for managing and deploying Vault Contract.
 * @dev    Vault are deployed as individual `Vault` contracts, A creation fee is required
 *         releaseTime are exressed in days
 */
contract VaultFactory {
    enum ApprovalState {
        PENDING,
        APPROVED
    }

    /******************************************************************************
     *                              Struct                                         *
     ******************************************************************************/

    struct VaultInfo {
        address vaultAddress;
        address creatorAddress;
        uint256 amount;
        bool isAutomated;
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

    LinkTokenInterface public immutable i_link;
    IKeeperRegistrar public immutable i_registrar;
    ApprovalState private approvalState;

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
    error VaultFactory__RegistrationFailed();

    /******************************************************************************
     *                                   Events                                   *
     ******************************************************************************/

    event CreatedVault(
        address indexed creator,
        uint256 amount,
        uint256 counter,
        uint256 upKeepId
    );

    constructor(address _linkToken, address _registerAddress) {
        i_link = LinkTokenInterface(_linkToken);
        i_registrar = IKeeperRegistrar(_registerAddress);
    }

    /******************************************************************************
     *                             External Functions                             *
     ******************************************************************************/

    function createVault(
        uint256 amountInWei,
        uint256 linkAmount,
        uint256 releaseTime,
        address[] calldata beneficiaries
    ) external payable returns (address, uint256 upkeepID) {
        address sender = msg.sender;
        uint256 value = msg.value;

        uint256 _releaseTime = releaseTime * 1 days;
        i_link.transferFrom(msg.sender, address(this), linkAmount);

        _createVaultAuthentication(
            value,
            amountInWei,
            _releaseTime,
            beneficiaries
        );

        i_link.transferFrom(msg.sender, address(this), linkAmount);

        Vault _vault = new Vault(
            sender,
            address(this),
            amountInWei,
            block.timestamp + _releaseTime,
            beneficiaries
        );

        address _vaultAddr = address(_vault);

        upkeepID = _registerAndPredictID(_vaultAddr);

        sVaultInfo[svaultCounter] = VaultInfo({
            vaultAddress: _vaultAddr,
            creatorAddress: sender,
            amount: amountInWei,
            isAutomated: upkeepID == 0 ? false : true,
            releaseTime: block.timestamp + _releaseTime
        });

        sIsVault[_vaultAddr] = true;
        sIsFactory[_vaultAddr] = address(this);

        svaultCounter++;

        emit CreatedVault(sender, amountInWei, svaultCounter, upkeepID);

        //refund any eth sent above sminimumEth

        if (value > CREATION_FEE) {
            uint256 refund = value - CREATION_FEE;
            (bool sucess, ) = payable(sender).call{value: refund}("");
            require(sucess, "Refund failed");
        }

        return (_vaultAddr, upkeepID);
    }

    /******************************************************************************
     *                             internal functions                             *
     ******************************************************************************/

    function _createVaultAuthentication(
        uint256 value,
        uint256 amountInWei,
        uint256 _releaseTime,
        address[] calldata beneficiaries
    ) internal {
        if (value < CREATION_FEE) revert VaultFactory__InsuffcientCreationFee();
        if (amountInWei == 0) revert VaultFactory__ZeroValueAmount();
        if (amountInWei < sminimumEth)
            revert VaultFactory__LessThanMinimumEth();

        if (_releaseTime == 0) revert VaultFactory__InvalidRealeaseTime();
        if (_releaseTime <= 10 days)
            revert VaultFactory__RealeaseTimeTooEarly();

        if (beneficiaries.length == 0)
            revert VaultFactory__NoBeneficiaryAdded();
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
    }

    function _registerAndPredictID(
        address _vault
    ) internal returns (uint256 upKeedID) {
        // LINK must be approved for transfer (same comment as Chainlink example)
        // taking link from the contract address
        uint96 linkAmount = 2000000000000000000;
        i_link.approve(address(i_registrar), linkAmount);

        //register the upkeep

        upKeedID = IKeeperRegistrar(i_registrar).registerUpkeep(
            IKeeperRegistrar.RegistrationParams({
                name: string(abi.encodePacked("Vault", _toHex(_vault))),
                encryptedEmail: bytes(""),
                upkeepContract: _vault,
                gasLimit: 500000,
                adminAddress: msg.sender,
                triggerType: 0, // 0 = conditional (checkUpkeep polling)
                checkData: bytes(""),
                triggerConfig: bytes(""),
                offchainConfig: bytes(""),
                amount: linkAmount //amount of link paid for upkeep
            })
        );
        if (upKeedID == 0) revert VaultFactory__RegistrationFailed();
    }

    /******************************************************************************
     *                               View Functions                               *
     ******************************************************************************/

    function isUserBeneficiary(address user) public view returns (bool) {
        return isBeneficiaries[user];
    }

    function getVaultCount() public view returns (uint256) {
        return svaultCounter;
    }

    function isValidVault(address vaultAddr) public view returns (bool) {
        return sIsVault[vaultAddr];
    }

    function getVault(uint256 vaultId) public view returns (VaultInfo memory) {
        return sVaultInfo[vaultId];
    }

    function getVaultAddress(uint256 vaultId) public view returns (address) {
        return sVaultInfo[vaultId].vaultAddress;
    }

    function getFactoryOf(address vaultAddress) public view returns (address) {
        return sIsFactory[vaultAddress];
    }

    /******************************************************************************
     *                                  Helpers                                   *
     ******************************************************************************/

    function _toHex(address addr) internal pure returns (string memory) {
        bytes memory hex_ = "0123456789abcdef";
        bytes20 b = bytes20(addr);

        //this function only converts first 4 bytes of the address, not the full 20 bytes.
        bytes memory s = new bytes(10);
        s[0] = "0";
        s[1] = "x";
        for (uint256 i = 0; i < 4; i++) {
            s[2 + i * 2] = hex_[uint8(b[i]) >> 4];
            s[3 + i * 2] = hex_[uint8(b[i]) & 0x0f];
        }
        return string(s);
    }
}
