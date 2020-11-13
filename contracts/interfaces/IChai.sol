// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './IERC2612.sol';

/// @dev interface for the chai contract
/// Taken from https://github.com/makerdao/developerguides/blob/master/dai/dsr-integration-guide/dsr.sol
interface IChai is IERC20, IERC2612 {
    function move(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);

    function dai(address usr) external returns (uint256 wad);

    function join(address dst, uint256 wad) external;

    function exit(address src, uint256 wad) external;

    function draw(address src, uint256 wad) external;
}
