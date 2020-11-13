// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

import '../interfaces/IFlashMinter.sol';
import '../interfaces/IFYDai.sol';

contract FlashMinterMock is IFlashMinter {
    event Parameters(uint256 amount, bytes data);

    uint256 public flashBalance;

    function executeOnFlashMint(uint256 fyDaiAmount, bytes calldata data) external override {
        flashBalance = IFYDai(msg.sender).balanceOf(address(this));
        emit Parameters(fyDaiAmount, data);
    }

    function flashMint(
        address fyDai,
        uint256 amount,
        bytes calldata data
    ) public {
        IFYDai(fyDai).flashMint(amount, data);
    }
}
