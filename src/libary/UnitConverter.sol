// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

library UnitConverter {
    function ethToWeiConverter(uint256 value) internal pure returns (uint256) {
        return value * 1e18;
    }
}
