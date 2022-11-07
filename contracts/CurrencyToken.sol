// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./token/ERC20/ERC20.sol";

contract CurrencyToken is ERC20 {

    constructor () ERC20("StableDollar", "$") {
        _mint(msg.sender, 1000000 * (10 ** uint256(decimals())));
    }
}