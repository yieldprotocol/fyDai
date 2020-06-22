pragma solidity ^0.6.0;

// import "@hq20/contracts/contracts/access/AuthorizedAccess.sol";
import "@hq20/contracts/contracts/math/DecimalMath.sol";
import "@hq20/contracts/contracts/utils/SafeCast.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IVat.sol";
import "./interfaces/IDaiJoin.sol";
import "./interfaces/IGemJoin.sol";
import "./interfaces/IEnd.sol";
import "./interfaces/IChai.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IYDai.sol";
import "./Constants.sol";
import "@nomiclabs/buidler/console.sol";


/// @dev Treasury manages the Dai, interacting with MakerDAO's vat and chai when needed.
contract DssShutdown is Constants {
    using DecimalMath for uint256;
    // using DecimalMath for int256;
    // using DecimalMath for uint8;
    using SafeCast for uint256;
    // using SafeCast for int256;

    bytes32 constant collateralType = "ETH-A";

    IVat internal _vat;
    IDaiJoin internal _daiJoin;
    IERC20 internal _weth;
    IGemJoin internal _wethJoin;
    IEnd internal _end;
    IChai internal _chai;
    IOracle internal _chaiOracle;
    ITreasury internal _treasury;
    IVault internal _dealer;

    mapping(address => uint256) public posted; // TODO: Remove
    mapping(uint256 => mapping(address => uint256)) public debtYDai; // TODO: Remove

    uint256 public _fix; // Dai to weth price on DSS Shutdown
    uint256 public _chi; // Chai to dai price on DSS Shutdown

    bool public live;
    bool public settled;
    bool public cashedOut;

    constructor (
        address vat_,
        address daiJoin_,
        address weth_,
        address wethJoin_,
        address end_,
        address chai_,
        address chaiOracle_,
        address treasury_,
        address dealer_
    ) public {
        // These could be hardcoded for mainnet deployment.
        _vat = IVat(vat_);
        _daiJoin = IDaiJoin(daiJoin_);
        _weth = IERC20(weth_);
        _wethJoin = IGemJoin(wethJoin_);
        _end = IEnd(end_);
        _chai = IChai(chai_);
        _chaiOracle = IOracle(chaiOracle_);
        _treasury = ITreasury(treasury_);
        _dealer = IVault(dealer_);

        _vat.hope(address(_treasury));
        _vat.hope(address(_end));
        live = true;
    }

    /// @dev Disables treasury and dealer.
    function shutdown() public {
        require(
            _end.tag(collateralType) != 0,
            "DssShutdown: MakerDAO not shutting down"
        );
        live = false;
        _treasury.shutdown();
        _dealer.shutdown();
    }

    /// @dev max(0, x - y)
    function subFloorZero(uint256 x, uint256 y) public pure returns(uint256) {
        if (y >= x) return 0;
        else return x - y;
    }

    /// @dev Settle system debt in MakerDAO and free remaining collateral.
    function settleTreasury() public {
        require(
            live == false,
            "DssShutdown: Shutdown first"
        );
        (uint256 ink, uint256 art) = _vat.urns("ETH-A", address(_treasury));
        _vat.fork(                                               // Take the treasury vault
            collateralType,
            address(_treasury),
            address(this),
            ink.toInt(),
            art.toInt()
        );
        _end.skim(collateralType, address(this));                // Settle debts
        _end.free(collateralType);                               // Free collateral
        uint256 gem = _vat.gem("ETH-A", address(this));          // Find out how much collateral we have now
        _wethJoin.exit(address(this), gem);                      // Take collateral out
        settled = true;
    }

    /// @dev Put all chai savings in MakerDAO and exchange them for weth
    function cashSavings() public {
        require(
            _end.tag(collateralType) != 0,
            "DssShutdown: End.sol not caged"
        );
        require(
            _end.fix(collateralType) != 0,
            "DssShutdown: End.sol not ready"
        );
        uint256 daiTokens = _chai.dai(address(_treasury));   // Find out how much is the chai worth
        _chai.draw(address(_treasury), _treasury.savings()); // Get the chai as dai
        _daiJoin.join(address(this), daiTokens);             // Put the dai into MakerDAO
        _end.pack(daiTokens);                                // Into End.sol, more exactly
        _end.cash(collateralType, daiTokens);                // Exchange the dai for weth
        uint256 gem = _vat.gem("ETH-A", address(this));      // Find out how much collateral we have now
        _wethJoin.exit(address(this), gem);                  // Take collateral out
        cashedOut = true;

        _fix = _end.fix(collateralType);
        _chi = _chaiOracle.price();
    }

    /// @dev Settles a series position in Dealer, and then returns any remaining collateral as weth using the shutdown Dai to Weth price.
    function settle(bytes32 collateral, address user) public {
        require(settled && cashedOut, "DssShutdown: Not ready");
        (uint256 tokenAmount, uint256 daiAmount) = _dealer.erase(collateral, user);
        uint256 remainder;
        if (collateral == WETH) {
            remainder = subFloorZero(tokenAmount, daiAmount.muld(_fix, RAY));
        } else if (collateral == CHAI) {
            remainder = subFloorZero(tokenAmount.muld(_chi, RAY), daiAmount).muld(_fix, RAY);
        }
        _weth.transfer(user, remainder);
    }

    /// @dev Redeems YDai for weth
    function redeem(uint256 maturity, uint256 yDaiAmount, address user) public {
        require(settled && cashedOut, "DssShutdown: Not ready");
        IYDai yDai = _dealer.series(maturity);
        yDai.burn(user, yDaiAmount);
        _weth.transfer(
            user,
            yDaiAmount.muld(yDai.chiGrowth(), RAY).muld(_fix, RAY)
        );
    }

    /// @dev Removes any system profit. Can only be executed once all user debt has been resolved,
    /// defined as the existing amount of yDai of all maturities combined.
    function profit(address user) public {
        require(settled && cashedOut, "DssShutdown: Not ready");
        require(
            _dealer.systemDebt() == 0,
            "DssShutdown: Redeem all yDai"
        );
        // TODO: Hardcode the address
        _weth.transfer(user, _weth.balanceOf(address(this)));
    }
}