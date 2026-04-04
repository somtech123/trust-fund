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
    }

    function setBalance(
        address _address,
        uint256 _value
    ) external returns (bool) {
        _transfer(address(this), _address, _value);

        return true;
    }
}
