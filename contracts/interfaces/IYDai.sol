pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IYDai is IERC20 {
    function isMature() external view returns(bool);
    function maturity() external view returns(uint);
    function chi0() external view returns(uint);
    function rate0() external view returns(uint);
    function chiGrowth() external returns(uint);
    function rateGrowth() external returns(uint);
    function mature() external;
    function mint(address, uint) external;
    function burn(address, uint) external;
    function flashMint(address, uint128, bytes calldata) external;
    // function transfer(address, uint) external returns (bool);
    // function transferFrom(address, address, uint) external returns (bool);
    // function approve(address, uint) external returns (bool);
}