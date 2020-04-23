pragma solidity ^0.5.2;

import "@hq20/contracts/contracts/math/DecimalMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "./interfaces/IVat.sol";
import "./interfaces/IPot.sol";
import "./Constants.sol";
import "./YToken.sol";


///@dev yDai is a yToken targeting Dai
contract YDai is YToken, Constants {
    using DecimalMath for uint256;
    using DecimalMath for uint8;

    event Matured(uint256 rate, uint256 chi);

    IVat public vat;
    IPot public pot;

    uint256 public maturityChi;  // accumulator (for dsr) at maturity in RAY units
    uint256 public maturityRate; // accumulator (for stability fee) at maturity in RAY units

    constructor(
        address underlying_,
        address collateral_,
        address vat_,
        address pot_,
        uint256 maturity_
    ) YToken(underlying_, collateral_, maturity_) public {
        vat = IVat(vat_);
        pot = IPot(pot_);
    }

    /// @dev Return debt in underlying of an user
    function debtOf(address user) public view returns (uint256) {
        if (isMature){
            (, uint256 rate,,,) = vat.ilks("ETH-A");
            return debt[user].muld(rate.divd(maturityRate, RAY), RAY);
        } else {
            return debt[user];
        }
    }

    /// @dev Mature yToken to make redeemable.
    function mature() public returns (bool) {
        require(
            // solium-disable-next-line security/no-block-members
            now > maturity,
            "YToken: Too early to mature"
        );
        (, maturityRate,,,) = vat.ilks("ETH-A"); // Retrieve the MakerDAO DSR
        maturityRate = Math.max(maturityRate, RAY.unit()); // Floor it at 1.0
        maturityChi = pot.chi();
        isMature = true;
        emit Matured(maturityRate, maturityChi);
        return true;
    }
}