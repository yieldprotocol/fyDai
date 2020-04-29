pragma solidity ^0.6.2;

///@dev yDai is a yToken targeting Dai
interface IYDai{
    /// @dev Mature yDai and capture maturity data
    function mature() external;

    /// @dev Mint yDai. Only callable by its Controller contract.
    function mint(address user, uint256 amount) external;

    /// @dev Burn yDai. Only callable by its Controller contract.
    function burn(address user, uint256 amount) external;
}