pragma solidity ^0.5.2;

import "@hq20/contracts/contracts/math/DecimalMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IVault.sol";
import "./Constants.sol";


contract Vault is Ownable, Constants {
    using DecimalMath for uint256;

    event CollateralLocked(address collateral, address user, uint256 amount);

    // TODO: Use address(0) to represent Ether, consider also using an ERC20 Ether wrapper
    IERC20 internal collateral;
    uint256 public ratio; // collateralization ratio, in RAY units
    uint256 public minRatio; // minimum collateralization ratio, in RAY units
    IOracle internal oracle;
    mapping(address => uint256) internal posted; // In collateral
    mapping(address => uint256) internal locked; // In collateral

    constructor (address collateral_, address oracle_, uint256 ratio_, uint256 minRatio_) public Ownable() {
        collateral = IERC20(collateral_);
        oracle = IOracle(oracle_);
        ratio = ratio_;
        minRatio = minRatio_;
    }

    /// @dev Return posted collateral of an user
    function balanceOf(address user) public view returns (uint256) {
        // No need for SafeMath, can't lock more than you have.
        return posted[user];
    }

    /// @dev Return unlocked collateral of an user
    function unlockedOf(address user) public view returns (uint256) {
        // No need for SafeMath, can't lock more than you have.
        return posted[user] - locked[user];
    }

    /// @dev Post collateral
    /// TODO: Allow posting for others with Ownable
    function post(uint256 amount) public returns (bool) {
        require(
            collateral.transferFrom(msg.sender, address(this), amount) == true,
            "Vault: Transfer failed"
        ); // No need for extra events
        posted[msg.sender] += amount; // No need for SafeMath, can't overflow.
        return true;
    }

    /// @dev Retrieve collateral
    /// TODO: Allow retrieving for others with Ownable
    function retrieve(uint256 amount) public returns (bool) {
        require(
            unlockedOf(msg.sender) >= amount,
            "Vault: Unlock more collateral"
        );
        require(
            collateral.transfer(msg.sender, amount) == true,
            "Vault: Failed transfer"
        ); // No need for extra events
        posted[msg.sender] -= amount; // No need for SafeMath, we are checking first.
        return true;
    }

    /// @dev Lock collateral equivalent to an amount of underlying
    /// This function can be called repeatedly to update the locked collateral as price changes
    function lock(address user, uint256 amount) public onlyOwner returns (bool) {
        uint256 collateralAmount = collateralNeeded(amount);
        require(
            balanceOf(user) >= collateralAmount,
            "Vault: Not enough collateral"
        );
        locked[user] = collateralAmount; // No need for SafeMath, can't overflow.
        emit CollateralLocked(address(collateral), user, collateralAmount);
        return true;
    }

    /// @dev Return whether a position is collateralized
    function isCollateralized(address user, uint256 amount) public view returns (bool) {
        return locked[user] >= collateralNeeded(amount);
    }

    /// @dev Return whether a position is under collateralized
    function isUnderCollateralized(address user, uint256 amount) public view returns (bool) {
        return locked[user] >= minCollateralNeeded(amount);
    }

    /// @dev Return how much collateral is needed to collateralize an amount of underlying
    function collateralNeeded(uint256 amount) public view returns (uint256) {
        // TODO: Think about oracle decimals
        // TODO: Do I have to worry about the oracle returning zero?
        // TODO: What happens for tiny amounts that get divided to zero?
        // (amount / price) * ratio
        return amount.muld(oracle.get(), WAD).muld(ratio, RAY);
    }

    /// @dev Return how much collateral is needed to maintain collateralization on an amount of underlying
    function minCollateralNeeded(uint256 amount) public view returns (uint256) {
        // TODO: Think about oracle decimals
        // TODO: Do I have to worry about the oracle returning zero?
        // TODO: What happens for tiny amounts that get divided to zero?
        // (amount / price) * minRatio
        return amount.muld(oracle.get(), WAD).muld(minRatio, RAY);
    }
}
