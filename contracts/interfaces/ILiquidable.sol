pragma solidity ^0.6.2;


/// @dev interface for liquidable debt vaults
interface ILiquidable {
    function posted(address user) external view returns (uint256);
    function isUndercollateralized(address user) external returns (bool);
    function debtDai(address user) external view returns (uint256);
    function liquidate(address from, address to, uint amount) external;
    function target(address user, uint256 fee) external;
}