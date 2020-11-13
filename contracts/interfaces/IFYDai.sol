// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './IERC2612.sol';

interface IFYDai is IERC20, IERC2612 {
    function isMature() external view returns (bool);

    function maturity() external view returns (uint256);

    function chi0() external view returns (uint256);

    function rate0() external view returns (uint256);

    function chiGrowth() external view returns (uint256);

    function rateGrowth() external view returns (uint256);

    function mature() external;

    function unlocked() external view returns (uint256);

    function mint(address, uint256) external;

    function burn(address, uint256) external;

    function flashMint(uint256, bytes calldata) external;

    function redeem(
        address,
        address,
        uint256
    ) external returns (uint256);
    // function transfer(address, uint) external returns (bool);
    // function transferFrom(address, address, uint) external returns (bool);
    // function approve(address, uint) external returns (bool);
}
