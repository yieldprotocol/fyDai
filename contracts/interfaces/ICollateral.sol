pragma solidity ^0.6.2;


interface ICollateral {
    /// @dev collateral/dai price * collateralizationRatio in ray
    function multiplier() external view returns (uint256);
}
