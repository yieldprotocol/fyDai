pragma solidity ^0.6.2;


/// @dev interface for the pot contract from MakerDao
/// Taken from https://github.com/makerdao/developerguides/blob/master/dai/dsr-integration-guide/dsr.sol
interface IPot {
    function chi() external view returns (uint256);
    // function rho() external returns (uint256);
    // function drip() external returns (uint256);
    function join(uint256) external;
    function exit(uint256) external;
    function pie(address) external view returns (uint256);
}