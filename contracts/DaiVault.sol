pragma solidity ^0.6.2;

import "@hq20/contracts/contracts/math/DecimalMath.sol";
import "@hq20/contracts/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "./interfaces/IDaiJoin.sol";
import "./interfaces/IPot.sol";
import "./interfaces/IVat.sol";
import "./interfaces/IVault.sol";
import "./Constants.sol";


/// @dev Treasury is the bottom layer that moves all assets.
contract DaiVault is IVault, Ownable, Constants {
    using DecimalMath for uint256;
    using DecimalMath for int256;
    using DecimalMath for uint8;
    using SafeCast for uint256;

    IERC20 public dai;
    // Maker join contracts:
    // https://github.com/makerdao/dss/blob/master/src/join.sol
    IDaiJoin public daiJoin;
    // Maker vat contract:
    IVat public vat;
    IPot public pot;

    int256 daiBalance; // Could this be retrieved as dai.balanceOf(address(this)) - something?
    // uint256 ethBalance; // This can be retrieved as weth.balanceOf(address(this))
    bytes32 collateralType = "ETH-A";

    /// @dev Moves Dai from user into Treasury controlled Maker Dai vault
    function push(address from, uint256 amount) public {
        require(
            dai.transferFrom(from, address(this), amount),
            "YToken: DAI transfer fail"
        ); // TODO: Check dai behaviour on failed transfers
        // With the split I'm not sure about this, can we use the Controller address everywhere here and in EthVault.sol?
        (, uint256 normalizedDebt) = vat.urns(collateralType, address(this));
        if (normalizedDebt > 0){
            // repay as much debt as possible
            (, uint256 rate,,,) = vat.ilks(collateralType);
            // Normalized Dai to receive - wad
            int256 dart = amount.divd(rate, ray).toInt256(); // `amount` and `rate` are positive
            maturityRate = Math.min(dart, ray.unit()); // only repay up to total in
            _repayDai(dart);
        } else {
            // put funds in the DSR
            _lockDai();
        }
    }

    /// @dev moves Dai from Treasury to user, borrowing from Maker DAO if not enough present.
    /// TODO: This function requires authorization to use
    function pull(address to, uint256 amount) public {
        uint256 chi = pot.chi();
        uint256 normalizedBalance = pot.pie(address(this));
        uint256 balance = normalizedBalance.muld(chi, ray);
        if (balance > toSend) {
            //send funds directly
            uint256 normalizedAmount = amount.divd(chi, ray);
            _freeDai(normalizedAmount);
            require(
                dai.transfer(to, amount),
                "YToken: DAI transfer fail"
            ); // TODO: Check dai behaviour on failed transfers
        } else {
            //borrow funds and send them
            _borrowDai(to, amount);
        }
    }

    /// @dev Mint an `amount` of Dai
    function _borrowDai(address to, uint256 amount) internal {
        // Add Dai to vault
        // collateral to add - wad
        int256 dink = 0; // Delta ink, change in collateral balance
        // Normalized Dai to receive - wad
        (, rate,,,) = vat.ilks("ETH-A"); // Retrieve the MakerDAO stability fee
        // collateral to add -- all collateral should already be present
        int256 dart = -amount.divd(rate, ray).toInt256(); // Delta art, change in dai debt
        // Normalized Dai to receive - wad
        // frob alters Maker vaults
        vat.frob(
            collateralType,
            address(this),
            address(this),
            address(this),
            dink,
            dart
        ); // `vat.frob` reverts on failure
        daiJoin.exit(to, amount); // `daiJoin` reverts on failures
    }

        /// @dev Moves Dai from user into Treasury controlled Maker Dai vault
    function _repayDai(uint256 dart) internal {
        // TODO: Check dai behaviour on failed transfers
        daiJoin.join(address(this), amount);
        // Add Dai to vault
        // collateral to add - wad
        int256 dink = 0;
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

    /// @dev lock all Dai in the DSR
    function _lockDai() internal {
        uint256 balance = dai.balanceOf(address(this));
        uint256 chi = pot.chi();
        uint256 normalizedAmount = balance.divd(chi, ray);
        pot.join(normalizedAmount);
    }

    /// @dev remove Dai from the DSR
    function _freeDai(uint256 amount) internal {
        uint256 chi = pot.chi();
        uint256 normalizedAmount = amount.divd(chi, ray);
        pot.exit(normalizedAmount);
    }
}
