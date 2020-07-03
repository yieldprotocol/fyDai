pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IYDai is IERC20 {
    function isMature() external view returns(bool);
    function maturity() external view returns(uint128);
    function chi0() external view returns(uint128);
    function rate0() external view returns(uint128);
    function chiGrowth() external returns(uint128);
    function rateGrowth() external returns(uint128);
    function mature() external;
    function mint(address, uint128) external;
    function burn(address, uint128) external;
    function flashMint(address, uint128, bytes calldata) external;
    // function transfer(address, uint) external returns (bool);
    // function transferFrom(address, address, uint) external returns (bool);
    // function approve(address, uint) external returns (bool);
}