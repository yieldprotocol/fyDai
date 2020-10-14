// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

import "./TestERC20.sol";

contract TestFYDai is TestERC20 {
    uint256 public maturity;

    constructor (uint256 supply, uint256 maturity_) public TestERC20(supply) {
        maturity = maturity_;
    }
}
