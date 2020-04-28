pragma solidity ^0.6.2;

import "@hq20/contracts/contracts/math/DecimalMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IGemJoin.sol";
import "./interfaces/IVat.sol";
import "./interfaces/IVault.sol";
import "./Constants.sol";


/// @dev EthVault interfaces with a WETH Maker Vault
contract EthVault is IVault, Ownable, Constants {
    using DecimalMath for uint256;
    using DecimalMath for int256;
    using DecimalMath for uint8;

    IERC20 public weth;
    // Maker join contracts:
    // https://github.com/makerdao/dss/blob/master/src/join.sol
    IGemJoin public wethJoin;
    // Maker vat contract:
    IVat public vat;

    // uint256 ethBalance; // This can be retrieved as weth.balanceOf(address(this))
    bytes32 collateralType = "ETH-A";

    /// @dev Moves Eth collateral from user into Treasury controlled Maker Eth vault
    function push(address from, uint256 amount) public {
        require(
            weth.transferFrom(from, address(this), amount),
            "YToken: WETH transfer fail"
        );
        weth.approve(address(wethJoin), amount);
        // With the split I'm not sure about this, can we use the Controller address everywhere here and in DaiVault.sol?
        wethJoin.join(address(this), amount); // GemJoin reverts if anything goes wrong.
        // All added collateral should be locked into the vault
        // collateral to add - wad
        int256 dink = amount.toInt256();
        // Normalized Dai to receive - wad
        int256 dart = 0;
        // frob alters Maker vaults
        vat.frob(
            collateralType,
            address(this),
            address(this),
            address(this),
            dink,
            dart
        ); // `vat.frob` reverts on failure
    }

    /// @dev Moves Eth collateral from Treasury controlled Maker Eth vault back to user
    /// TODO: This function requires authorization to use
    function pull(address to, uint256 amount) public {
        // Remove collateral from vault
        // collateral to add - wad
        int256 dink = -amount.toInt256();
        // Normalized Dai to receive - wad
        int256 dart = 0;
        // frob alters Maker vaults
        vat.frob(
            collateralType,
            address(this),
            address(this),
            address(this),
            dink,
            dart
        ); // `vat.frob` reverts on failure
        wethJoin.exit(to, amount); // `GemJoin` reverts on failures
    }
}
