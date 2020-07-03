pragma solidity ^0.6.0;

// import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IVat.sol";
import "./interfaces/IJug.sol";
import "./interfaces/IPot.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IYDai.sol";
import "./interfaces/IFlashMinter.sol";
import "./helpers/Delegable.sol";
// import "./helpers/DecimalMath.sol";
import "./helpers/Orchestrated.sol";
import "@nomiclabs/buidler/console.sol";


/// @dev yDai is a yToken targeting Dai.
contract YDai is Orchestrated(), Delegable(), /* DecimalMath, */ ERC20/*, IYDai */ {
    // --- TEMP

    uint256 constant public UNIT = 1000000000000000000000000000;

    /// @dev Multiplies x and y, assuming they are both fixed point with 27 digits.
    function muld(uint128 x, uint128 y) internal pure returns (uint128) {
        return uint128(uint256(x) * uint256(y) / UNIT);
    }

    /// @dev Divides x between y, assuming they are both fixed point with 18 digits.
    function divd(uint128 x, uint128 y) internal pure returns (uint128) {
        return uint128(uint256(x) * UNIT / uint256(y));
    }

    function max(uint128 a, uint128 b) internal pure returns (uint128) {
        return a > b ? a : b;
    }

    function min(uint128 a, uint128 b) internal pure returns (uint128) {
        return a < b ? a : b;
    }
    // --- TEMP

    event Redeemed(address indexed user, uint128 yDaiIn, uint128 daiOut);
    event Matured(uint128 rate, uint128 chi);

    IVat internal _vat;
    IJug internal _jug;
    IPot internal _pot;
    ITreasury internal _treasury;

    bool public /* override */ isMature;
    uint256 public /* override */ maturity;
    uint128 public /* override */ chi0;      // Chi at maturity
    uint128 public /* override */ rate0;     // Rate at maturity

    constructor(
        address vat_,
        address jug_,
        address pot_,
        address treasury_,
        uint256 maturity_,
        string memory name,
        string memory symbol
    ) public ERC20(name, symbol) {
        _vat = IVat(vat_);
        _jug = IJug(jug_);
        _pot = IPot(pot_);
        _treasury = ITreasury(treasury_);
        maturity = maturity_;
        chi0 = uint128(UNIT);
        rate0 = uint128(UNIT);
    }

    /// @dev Chi differential between maturity and now in RAY. Returns 1.0 if not mature.
    /// If rateGrowth < chiGrowth, returns rate.
    //
    //          chi_now
    // chi() = ---------
    //          chi_mat
    //
    function chiGrowth() public /* override */ returns(uint128){
        if (isMature != true) return chi0;
        uint128 chiNow = uint128((now > _pot.rho()) ? _pot.drip() : _pot.chi());
        return /* Math. */min(rateGrowth(), divd(chiNow, chi0));
    }

    /// @dev Rate differential between maturity and now in RAY. Returns 1.0 if not mature.
    //
    //           rate_now
    // rateGrowth() = ----------
    //           rate_mat
    //
    function rateGrowth() public /* override */ returns(uint128){
        if (isMature != true) return rate0;
        uint256 rateNow;
        (, uint256 rho) = _jug.ilks("ETH-A"); // "WETH" for weth.sol, "ETH-A" for MakerDAO
        if (now > rho) {
            rateNow =_jug.drip("ETH-A");
            // console.log(rateNow);
        } else {
            (, rateNow,,,) = _vat.ilks("ETH-A");
        }
        return divd(uint128(rateNow), rate0);
    }

    /// @dev Mature yDai and capture maturity data
    function mature() public /* override */ {
        require(
            // solium-disable-next-line security/no-block-members
            now > maturity,
            "YDai: Too early to mature"
        );
        require(
            isMature != true,
            "YDai: Already matured"
        );
        (, uint256 tmpRate,,,) = _vat.ilks("ETH-A"); // Retrieve the MakerDAO Vat
        rate0 = /* Math. */max(uint128(rate0), uint128(UNIT)); // Floor it at 1.0
        chi0 = uint128((now > _pot.rho()) ? _pot.drip() : _pot.chi());
        isMature = true;
        emit Matured(rate0, chi0);
    }

    /// @dev Burn yTokens and return their dai equivalent value, pulled from the Treasury
    // TODO: Consider whether to allow this to be gracefully unwind, instead of letting `_treasury.pullDai()` revert.
    // user --- yDai ---> us
    // us   --- Dai  ---> user
    function redeem(address user, uint128 yDaiAmount)
        public onlyHolderOrDelegate(user, "YDai: Only Holder Or Delegate") {
        require(
            isMature == true,
            "YDai: yDai is not mature"
        );
        _burn(user, yDaiAmount);                              // Burn yDai from user
        uint128 daiAmount = muld(yDaiAmount, chiGrowth());    // User gets interest for holding after maturity
        _treasury.pullDai(user, daiAmount);                   // Give dai to user, from Treasury
        emit Redeemed(user, yDaiAmount, daiAmount);
    }

    /// @dev Flash-mint yDai. Calls back on `IFlashMinter.executeOnFlashMint()`
    function flashMint(address to, uint128 yDaiAmount, bytes calldata data) external /* override */ {
        _mint(to, yDaiAmount);
        IFlashMinter(msg.sender).executeOnFlashMint(to, yDaiAmount, data);
        _burn(to, yDaiAmount);
    }

    /// @dev Mint yDai. Only callable by Dealer contracts.
    function mint(address to, uint128 yDaiAmount) public /* override */ onlyOrchestrated("YDai: Not Authorized")
        {
        _mint(to, yDaiAmount);
    }

    /// @dev Burn yDai. Only callable by Dealer contracts.
    function burn(address from, uint128 yDaiAmount) public /* override */ onlyOrchestrated("YDai: Not Authorized") {
        _burn(from, yDaiAmount);
    }
}