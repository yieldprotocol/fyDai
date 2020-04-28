pragma solidity ^0.6.2;


/// @dev Interface to interact with asset providers
interface IVault {
    function push(address source, uint256 amount) external;
    function pull(address receiver, uint256 amount) external;
}