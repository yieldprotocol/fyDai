// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

import "./IWeth.sol";
import "./IChai.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITreasury {
    function debt() external view returns(uint256);
    function savings() external view returns(uint256);
    function pushDai(address user, uint256 dai) external;
    function pullDai(address user, uint256 dai) external;
    function pushChai(address user, uint256 chai) external;
    function pullChai(address user, uint256 chai) external;
    function pushWeth(address to, uint256 weth) external;
    function pullWeth(address to, uint256 weth) external;
    function shutdown() external;
    function live() external view returns(bool);

    function weth() external view returns (IWeth);
    function chai() external view returns (IChai);
    function dai() external view returns (IERC20);
}
