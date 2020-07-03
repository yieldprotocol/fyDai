pragma solidity ^0.6.2;

import "../interfaces/IFlashMinter.sol";
import "../interfaces/IYDai.sol";


contract FlashMinterMock is IFlashMinter {

    event Parameters(address user, uint128 amount, bytes data);

    uint256 public flashBalance;

    function executeOnFlashMint(address to, uint128 yDaiAmount, bytes calldata data) external override {
        flashBalance = IYDai(msg.sender).balanceOf(address(this));
        emit Parameters(to, yDaiAmount, data);
    }

    function flashMint(address yDai, uint128 amount, bytes memory data) public {
        IYDai(yDai).flashMint(address(this), amount, data);
    }
}