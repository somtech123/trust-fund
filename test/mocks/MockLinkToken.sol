// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

// // import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Script, console} from "forge-std/Script.sol";

contract MockLinkToken is ERC20 {
    uint256 constant INITIAL_SUPPLY = 1_000_000 ether;
    uint8 constant DECIMALS = 18;

    constructor() ERC20("LinkToken", "LINK") {
        mint(address(this), INITIAL_SUPPLY);
    }

    function mint(address to, uint256 value) public {
        super._mint(to, value);
        console.log("-------------------------user blance", balanceOf(to));
    }

    function setBalance(
        address _address,
        uint256 _value
    ) external returns (bool) {
        _transfer(address(this), _address, _value);

        return true;
    }

    function approve(
        address spender,
        uint256 value
    ) public override returns (bool) {
        super.approve(spender, value);
        return true;
    }
}

contract MockLinkTokenReturnsFalse {
    function allowance(address, address) external pure returns (uint256) {
        return type(uint256).max; // always enough
    }

    function approve(address, uint256) public pure returns (bool) {
        return true;
    }

    // ...but returns false on transfer
    function transferFrom(
        address,
        address,
        uint256
    ) external pure returns (bool) {
        return false;
    }
}
