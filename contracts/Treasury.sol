pragma solidity ^0.6.0;

// import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IVat.sol";
import "./interfaces/IDaiJoin.sol";
import "./interfaces/IGemJoin.sol";
import "./interfaces/IPot.sol";
import "./interfaces/IChai.sol";
import "./interfaces/ITreasury.sol";
// import "./helpers/DecimalMath.sol";
import "./helpers/Orchestrated.sol";

// Test imports
import "@nomiclabs/buidler/console.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

/// @dev Treasury manages the Dai, interacting with MakerDAO's vat and chai when needed.
contract Treasury is ITreasury, Orchestrated()/*, DecimalMath*/ {
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

    /// @dev Divides x between y, rounding up to the closest representable number.
    /// Assumes x and y are both fixed point with `decimals` digits.
    function divdrup(uint128 x, uint128 y)
        internal pure returns (uint128)
    {
        uint256 z = uint256(x) * 10000000000000000000000000000 / uint256(y); // RAY * 10
        if (z % 10 > 0) return uint128(z / 10 + 1);
        else return uint128(z / 10);
    }

    function min(uint128 a, uint128 b) internal pure returns (uint128) {
        return a < b ? a : b;
    }
    // --- TEMP

    bytes32 constant collateralType = "ETH-A";

    IERC20 internal _dai;
    IChai internal _chai;
    IPot internal _pot;
    IERC20 internal _weth;
    IDaiJoin internal _daiJoin;
    IGemJoin internal _wethJoin;
    IVat internal _vat;
    address internal _unwind;

    bool public override live = true;

    constructor (
        address vat_,
        address weth_,
        address dai_,
        address wethJoin_,
        address daiJoin_,
        address pot_,
        address chai_
    ) public {
        // These could be hardcoded for mainnet deployment.
        _dai = IERC20(dai_);
        _chai = IChai(chai_);
        _pot = IPot(pot_);
        _weth = IERC20(weth_);
        _daiJoin = IDaiJoin(daiJoin_);
        _wethJoin = IGemJoin(wethJoin_);
        _vat = IVat(vat_);
        _vat.hope(wethJoin_);
        _vat.hope(daiJoin_);

        _dai.approve(address(_chai), uint256(-1));      // Chai will never cheat on us
        _weth.approve(address(_wethJoin), uint256(-1)); // WethJoin will never cheat on us
    }

    modifier onlyLive() {
        require(live == true, "Treasury: Not available during unwind");
        _;
    }

    /// @dev Safe casting from uint256 to uint128
    /* function toUint128(uint256 x) internal pure returns(uint128) {
        require(
            x <= 57896044618658097711785492504343953926634992332820282019728792003956564819967,
            "Treasury: Cast overflow"
        );
        return uint128(x);
    } */

    /// @dev Disables pulling and pushing. Can only be called if MakerDAO shuts down.
    function shutdown() public override {
        require(
            _vat.live() == 0,
            "Treasury: MakerDAO is live"
        );
        live = false;
    }

    /// @dev Returns the Treasury debt towards MakerDAO, as the dai borrowed times the stability fee for Weth.
    /// We have borrowed (rate * art)
    /// Borrowing Limit (rate * art) <= (ink * spot)
    function debt() public view override returns(uint128) {
        (, uint256 rate,,,) = _vat.ilks("ETH-A");            // Retrieve the MakerDAO stability fee for Weth
        (, uint256 art) = _vat.urns("ETH-A", address(this)); // Retrieve the Treasury debt in MakerDAO
        return muld(uint128(art), uint128(rate));
    }

    /// @dev Returns the Treasury borrowing capacity from MakerDAO, as the collateral posted times the collateralization ratio for Weth.
    /// We can borrow (ink * spot)
    function power() public view returns(uint128) {
        (,, uint256 spot,,) = _vat.ilks("ETH-A");            // Collateralization ratio for Weth
        (uint256 ink,) = _vat.urns("ETH-A", address(this));  // Treasury Weth collateral in MakerDAO
        return muld(uint128(ink), uint128(spot));
    }

    /// @dev Returns the amount of Dai in this contract.
    function savings() public override returns(uint128){
        return uint128(_chai.dai(address(this)));
    }

    /// @dev Takes dai from user and pays as much system debt as possible, saving the rest as chai.
    function pushDai(address from, uint128 amount) public override onlyOrchestrated("Treasury: Not Authorized") onlyLive  {
        require(
            _dai.transferFrom(from, address(this), amount),  // Take dai from user to Treasury
            "Dealer: Dai transfer fail"
        );

        uint128 toRepay =/* Math. */ min(debt(), amount);
        if (toRepay > 0) {
            _daiJoin.join(address(this), toRepay);
            // Remove debt from vault using frob
            (, uint256 rate,,,) = _vat.ilks("ETH-A"); // Retrieve the MakerDAO stability fee
            _vat.frob(
                collateralType,
                address(this),
                address(this),
                address(this),
                0,                           // Weth collateral to add
                -int256(divd(toRepay, uint128(rate)))  // Dai debt to remove
            );
        }

        uint128 toSave = amount - toRepay;         // toRepay can't be greater than dai
        if (toSave > 0) {
            _chai.join(address(this), toSave);    // Give dai to Chai, take chai back
        }
    }

    /// @dev Takes chai from user and pays as much system debt as possible, saving the rest as chai.
    function pushChai(address from, uint128 amount) public override onlyOrchestrated("Treasury: Not Authorized") onlyLive  {
        require(
            _chai.transferFrom(from, address(this), amount),
            "Treasury: Chai transfer fail"
        );
        uint128 dai = uint128(_chai.dai(address(this)));

        uint128 toRepay =/* Math. */ min(debt(), dai);
        if (toRepay > 0) {
            _chai.draw(address(this), toRepay);     // Grab dai from Chai, converted from chai
            _daiJoin.join(address(this), toRepay);
            // Remove debt from vault using frob
            (, uint256 rate,,,) = _vat.ilks("ETH-A"); // Retrieve the MakerDAO stability fee
            _vat.frob(
                collateralType,
                address(this),
                address(this),
                address(this),
                0,                           // Weth collateral to add
                -int256(divd(toRepay, uint128(rate)))  // Dai debt to remove
            );
        }
        // Anything that is left from repaying, is chai savings
    }

    /// @dev Takes Weth collateral from user into the system Maker vault
    function pushWeth(address from, uint128 amount) public override onlyOrchestrated("Treasury: Not Authorized") onlyLive  {
        require(
            _weth.transferFrom(from, address(this), amount),
            "Treasury: Weth transfer fail"
        );

        _wethJoin.join(address(this), amount); // GemJoin reverts if anything goes wrong.
        // All added collateral should be locked into the vault using frob
        _vat.frob(
            collateralType,
            address(this),
            address(this),
            address(this),
            int256(amount), // Collateral to add - WAD
            0 // Normalized Dai to receive - WAD
        );
    }

    /// @dev Returns dai using chai savings as much as possible, and borrowing the rest.
    function pullDai(address to, uint128 dai) public override onlyOrchestrated("Treasury: Not Authorized") onlyLive  {
        uint128 toRelease =/* Math. */ min(savings(), dai);
        if (toRelease > 0) {
            _chai.draw(address(this), toRelease);     // Grab dai from Chai, converted from chai
        }

        uint128 toBorrow = dai - toRelease;    // toRelease can't be greater than dai
        if (toBorrow > 0) {
            (, uint256 rate,,,) = _vat.ilks("ETH-A"); // Retrieve the MakerDAO stability fee
            // Increase the dai debt by the dai to receive divided by the stability fee
            _vat.frob(
                collateralType,
                address(this),
                address(this),
                address(this),
                0,
                int256(divd(toBorrow, uint128(rate)))
            ); // `vat.frob` reverts on failure
            _daiJoin.exit(address(this), toBorrow); // `daiJoin` reverts on failures
        }

        require(                            // Give dai to user
            _dai.transfer(to, dai),
            "Treasury: Dai transfer fail"
        );
    }

    /// @dev Returns chai using chai savings as much as possible, and borrowing the rest.
    function pullChai(address to, uint128 chai) public override onlyOrchestrated("Treasury: Not Authorized") onlyLive  {
        uint128 chi = uint128((now > _pot.rho()) ? _pot.drip() : _pot.chi());
        uint128 dai = muld(chai, chi);   // dai = price * chai
        uint128 toRelease =/* Math. */ min(savings(), dai);
        // As much chai as the Treasury has, can be used, we borrwo dai and convert it to chai for the rest

        uint128 toBorrow = dai - toRelease;    // toRelease can't be greater than dai
        if (toBorrow > 0) {
            (, uint256 rate,,,) = _vat.ilks("ETH-A"); // Retrieve the MakerDAO stability fee
            // Increase the dai debt by the dai to receive divided by the stability fee
            _vat.frob(
                collateralType,
                address(this),
                address(this),
                address(this),
                0,
                int256(divd(toBorrow, uint128(rate)))
            ); // `vat.frob` reverts on failure
            _daiJoin.exit(address(this), toBorrow);  // `daiJoin` reverts on failures
            _chai.join(address(this), toBorrow);     // Grab chai from Chai, converted from dai
        }

        require(                            // Give dai to user
            _chai.transfer(to, chai),
            "Treasury: Chai transfer fail"
        );
    }

    /// @dev Moves Weth collateral from Treasury controlled Maker Eth vault to `to` address.
    function pullWeth(address to, uint128 weth) public override onlyOrchestrated("Treasury: Not Authorized") onlyLive  {
        // Remove collateral from vault using frob
        _vat.frob(
            collateralType,
            address(this),
            address(this),
            address(this),
            -int256(weth), // Weth collateral to remove - WAD
            0              // Dai debt to add - WAD
        );
        _wethJoin.exit(to, weth); // `GemJoin` reverts on failures
    }

    /// @dev Registers the one contract that will take assets from the Treasury if MakerDAO shuts down.
    function registerUnwind(address unwind_) public onlyOwner {
        require(
            _unwind == address(0),
            "Treasury: Unwind already set"
        );
        _unwind = unwind_;
        _chai.approve(address(_unwind), uint256(-1)); // Unwind will never cheat on us
        _vat.hope(address(_unwind));                  // Unwind will never cheat on us
    }
}