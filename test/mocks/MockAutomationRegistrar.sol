// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

contract MockAutomationRegistrar {
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

    function registerUpkeep(
        RegistrationParams calldata params
    ) external returns (uint256) {
        return 1;
    }
}
