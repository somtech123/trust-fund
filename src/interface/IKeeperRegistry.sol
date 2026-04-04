// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.24;

interface IKeeperRegistrar {
    /**
     * @dev RegistrationParams struct used by KeeperRegistrar 2.1
     *      triggerType: 0 = conditional (checkUpkeep poll), 1 = log-based
     */
    struct RegistrationParams {
        string name;
        bytes encryptedEmail;
        address upkeepContract;
        uint32 gasLimit;
        address adminAddress;
        uint8 triggerType;
        bytes checkData;
        bytes triggerConfig;
        bytes offchainConfig;
        uint96 amount; // LINK amount (18 decimals)
    }

    /**
     * @notice Register a new upkeep. Caller must have approved `amount`
     *         LINK to this registrar before calling.
     * @return upkeepID The ID assigned by the registry.
     */
    function registerUpkeep(
        RegistrationParams calldata params
    ) external returns (uint256 upkeepID);
}
