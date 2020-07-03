pragma solidity ^0.6.2;

// import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IVat.sol";
import "./interfaces/IPot.sol";
import "./interfaces/IChai.sol";
import "./interfaces/IGasToken.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IDealer.sol";
import "./interfaces/IYDai.sol";
import "./helpers/Constants.sol";
import "./helpers/Delegable.sol";
// import "./helpers/DecimalMath.sol";
import "./helpers/Orchestrated.sol";
// import "@nomiclabs/buidler/console.sol";

/// @dev A dealer takes collateral and issues yDai.
contract Dealer is IDealer, Orchestrated(), Delegable(), /* DecimalMath, */ Constants {
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

    using SafeMath for uint128;

    event Posted(bytes32 indexed collateral, address indexed user, int256 amount);
    event Borrowed(bytes32 indexed collateral, uint256 indexed maturity, address indexed user, int256 amount);

    IVat internal _vat;
    IERC20 internal _dai;
    IPot internal _pot;
    IGasToken internal _gasToken;
    ITreasury internal _treasury;

    mapping(bytes32 => IERC20) internal _token;                       // Weth or Chai
    mapping(uint256 => IYDai) public override series;                 // YDai series, indexed by maturity
    uint256[] internal seriesIterator;                                // We need to know all the series

    mapping(bytes32 => mapping(address => uint128)) public override posted;               // Collateral posted by each user
    mapping(bytes32 => mapping(uint256 => mapping(address => uint128))) public debtYDai;  // Debt owed by each user, by series

    mapping(bytes32 => uint128) public override systemPosted;                        // Sum of collateral posted by all users
    mapping(bytes32 => mapping(uint256 => uint128)) public override systemDebtYDai;  // Sum of debt owed by all users, by series

    bool public live = true;

    constructor (
        address vat_,
        address weth_,
        address dai_,
        address pot_,
        address chai_,
        address gasToken_,
        address treasury_
    ) public {
        _vat = IVat(vat_);
        _dai = IERC20(dai_);
        _pot = IPot(pot_);
        _gasToken = IGasToken(gasToken_);
        _treasury = ITreasury(treasury_);
        _token[WETH] = IERC20(weth_);
        _token[CHAI] = IERC20(chai_);
    }

    modifier onlyLive() {
        require(live == true, "Dealer: Not available during unwind");
        _;
    }

    modifier validSeries(uint256 maturity) {
        require(
            containsSeries(maturity),
            "Dealer: Unrecognized series"
        );
        _;
    }

    modifier validCollateral(bytes32 collateral) {
        require(
            collateral == WETH || collateral == CHAI,
            "Dealer: Unrecognized collateral"
        );
        _;
    }

    /// @dev Disables post, withdraw, borrow and repay. To be called only when Treasury shuts down.
    function shutdown() public override {
        require(
            _treasury.live() == false,
            "Dealer: Treasury is live"
        );
        live = false;
    }

    /// @dev Returns if a series has been added to the Dealer, for a given series identified by maturity
    function containsSeries(uint256 maturity) public view returns (bool) {
        return address(series[maturity]) != address(0);
    }

    /// @dev Adds an yDai series to this Dealer
    function addSeries(address yDaiContract) public onlyOwner {
        uint256 maturity = IYDai(yDaiContract).maturity();
        require(
            !containsSeries(maturity),
            "Dealer: Series already added"
        );
        series[maturity] = IYDai(yDaiContract);
        seriesIterator.push(maturity);
    }

    /// @dev Returns the dai equivalent of an yDai amount, for a given series identified by maturity
    function inDai(bytes32 collateral, uint256 maturity, uint128 yDaiAmount) public returns (uint128) {
        if (series[maturity].isMature()){
            if (collateral == WETH){
                return muld(yDaiAmount, series[maturity].rateGrowth());
            } else if (collateral == CHAI) {
                return muld(yDaiAmount, series[maturity].chiGrowth());
            } else {
                revert("Dealer: Unsupported collateral");
            }
        } else {
            return yDaiAmount;
        }
    }

    /// @dev Returns the yDai equivalent of a dai amount, for a given series identified by maturity
    function inYDai(bytes32 collateral, uint256 maturity, uint128 daiAmount) public returns (uint128) {
        if (series[maturity].isMature()){
            if (collateral == WETH){
                return divd(daiAmount, series[maturity].rateGrowth());
            } else if (collateral == CHAI) {
                return divd(daiAmount, series[maturity].chiGrowth());
            } else {
                revert("Dealer: Unsupported collateral");
            }
        } else {
            return daiAmount;
        }
    }

    /// @dev Return debt in dai of an user, for a given collateral and series identified by maturity
    //
    //                        rate_now
    // debt_now = debt_mat * ----------
    //                        rate_mat
    //
    function debtDai(bytes32 collateral, uint256 maturity, address user) public returns (uint128) {
        return inDai(collateral, maturity, debtYDai[collateral][maturity][user]);
    }

    /// @dev Returns the total debt of an user, for a given collateral, across all series, in Dai
    function totalDebtDai(bytes32 collateral, address user) public override returns (uint128) {
        uint128 totalDebt;
        for (uint256 i = 0; i < seriesIterator.length; i += 1) {
            // TODO: Skip next line if debtYDai[collateral][maturity][user] == 0
            totalDebt = totalDebt + debtDai(collateral, seriesIterator[i], user);
        } // We don't expect hundreds of maturities per dealer
        return totalDebt;
    }

    /// @dev Maximum borrowing power of an user in dai for a given collateral
    //
    // powerOf[user](wad) = posted[user](wad) * oracle.price()(ray)
    //
    function powerOf(bytes32 collateral, address user) public returns (uint128) {
        // dai = price * collateral
        if (collateral == WETH){
            (,, uint256 spot,,) = _vat.ilks("ETH-A");  // Stability fee and collateralization ratio for Weth
            return muld(posted[collateral][user], uint128(spot));
        } else if (collateral == CHAI) {
            uint256 chi = (now > _pot.rho()) ? _pot.drip() : _pot.chi();
            return muld(posted[collateral][user], uint128(chi));
        }
        return 0;
    }

    /// @dev Return if the borrowing power for a given collateral of an user is equal or greater than its debt for the same collateral
    function isCollateralized(bytes32 collateral, address user) public override returns (bool) {
        return powerOf(collateral, user) >= totalDebtDai(collateral, user);
    }

    /// @dev Takes collateral _token from `from` address, and credits it to `to` collateral account.
    // from --- Token ---> us(to)
    function post(bytes32 collateral, address from, address to, uint128 amount)
        public override 
        validCollateral(collateral)
        onlyLive
    {
        if (collateral == WETH){ // TODO: Refactor Treasury to be `push(collateral, amount)`
            _treasury.pushWeth(from, amount);
        } else if (collateral == CHAI) {
            _treasury.pushChai(from, amount);
        }

        if (posted[collateral][to] == 0 && amount >= 0) {
            lockBond(10);
        }
        posted[collateral][to] = posted[collateral][to] + amount;
        systemPosted[collateral] = systemPosted[collateral] + amount;
        emit Posted(collateral, to, int256(amount));
    }

    /// @dev Returns collateral to `to` address, taking it from `from` collateral account.
    // us(from) --- Token ---> to
    function withdraw(bytes32 collateral, address from, address to, uint128 amount)
        public override
        validCollateral(collateral)
        onlyHolderOrDelegate(from, "Dealer: Only Holder Or Delegate")
        onlyLive
    {
        // TODO: Check enough collateral present.
        posted[collateral][from] = posted[collateral][from] - amount; // Will revert if not enough posted
        systemPosted[collateral] = systemPosted[collateral] - amount;

        require(
            isCollateralized(collateral, from),
            "Dealer: Too much debt"
        );

        if (collateral == WETH){ // TODO: Refactor Treasury to be `pull(collateral, amount)`
            _treasury.pullWeth(to, amount);
        } else if (collateral == CHAI) {
            _treasury.pullChai(to, amount);
        }

        if (posted[collateral][from] == 0 && amount >= 0) {
            returnBond(10);
        }
        emit Posted(collateral, to, -int256(amount));
    }

    /// @dev Mint yDai for a given series for address `to` by locking its market value in collateral, user debt is increased in the given collateral.
    //
    // posted[user](wad) >= (debtYDai[user](wad)) * amount (wad)) * collateralization (ray)
    //
    // us --- yDai ---> user
    // debt++
    function borrow(bytes32 collateral, uint256 maturity, address to, uint128 yDaiAmount)
        public
        validCollateral(collateral)
        validSeries(maturity)
        onlyHolderOrDelegate(to, "Dealer: Only Holder Or Delegate")
        onlyLive
    {
        require(
            series[maturity].isMature() != true,
            "Dealer: No mature borrow"
        );

        if (debtYDai[collateral][maturity][to] == 0 && yDaiAmount >= 0) {
            lockBond(10);
        }
        debtYDai[collateral][maturity][to] = debtYDai[collateral][maturity][to] + yDaiAmount;
        systemDebtYDai[collateral][maturity] = systemDebtYDai[collateral][maturity] + yDaiAmount;

        require(
            isCollateralized(collateral, to),
            "Dealer: Too much debt"
        );
        series[maturity].mint(to, yDaiAmount);
        emit Borrowed(collateral, maturity, to, int256(yDaiAmount));
    }

    /// @dev Burns yDai of a given series from `from` address, user debt is decreased for the given collateral and yDai series.
    //                                                  debt_nominal
    // debt_discounted = debt_nominal - repay_amount * ---------------
    //                                                  debt_now
    //
    // user --- yDai ---> us
    // debt--
    function repayYDai(bytes32 collateral, uint256 maturity, address from, uint128 yDaiAmount)
        public
        validCollateral(collateral)
        validSeries(maturity)
        onlyLive
    {
        uint128 toRepay = min(yDaiAmount, debtYDai[collateral][maturity][from]);
        series[maturity].burn(from, toRepay);
        _repay(collateral, maturity, from, toRepay);
    }

    /// @dev Takes dai from `from` address, user debt is decreased for the given collateral and yDai series.
    //                                                  debt_nominal
    // debt_discounted = debt_nominal - repay_amount * ---------------
    //                                                  debt_now
    //
    // user --- dai ---> us
    // debt--
    function repayDai(bytes32 collateral, uint256 maturity, address from, uint128 daiAmount)
        public
        validCollateral(collateral)
        validSeries(maturity)
        onlyLive
    {
        uint128 toRepay = min(daiAmount, debtDai(collateral, maturity, from));
        _treasury.pushDai(from, toRepay);                                      // Have Treasury process the dai
        _repay(collateral, maturity, from, inYDai(collateral, maturity, toRepay));
    }

    /// @dev Removes an amount of debt from an user's vault. If interest was accrued debt is only paid proportionally.
    //
    //                                                principal
    // principal_repayment = gross_repayment * ----------------------
    //                                          principal + interest
    //    
    function _repay(bytes32 collateral, uint256 maturity, address from, uint128 yDaiAmount)
        internal
    {
        debtYDai[collateral][maturity][from] = debtYDai[collateral][maturity][from] - yDaiAmount; // TODO: Doesn't need SafeMath
        systemDebtYDai[collateral][maturity] = systemDebtYDai[collateral][maturity] - yDaiAmount; // TODO: Doesn't need SafeMath
        if (debtYDai[collateral][maturity][from] == 0 && yDaiAmount >= 0) {
            returnBond(10);
        }
        emit Borrowed(collateral, maturity, from, -int256(yDaiAmount));
    }

    /// @dev Removes collateral and debt for an user.
    function grab(bytes32 collateral, address user, uint128 daiAmount, uint128 tokenAmount)
        public override
        validCollateral(collateral)
        onlyOrchestrated("Dealer: Not Authorized")
    {

        // TODO: Check there is enough collateral
        posted[collateral][user] = posted[collateral][user] - tokenAmount;
        systemPosted[collateral] = systemPosted[collateral] - tokenAmount; // TODO: Shouldn't need SafeMath
        if (posted[collateral][user] == 0){
            returnBond(10);
        }

        uint128 totalGrabbed;
        for (uint256 i = 0; i < seriesIterator.length; i += 1) {
            uint256 maturity = seriesIterator[i];
            uint128 thisGrab = min(debtDai(collateral, maturity, user), daiAmount - totalGrabbed); // TODO: SafeMath shouldn't be needed
            totalGrabbed = totalGrabbed + thisGrab; // TODO: SafeMath shouldn't be needed
            debtYDai[collateral][maturity][user] =
                debtYDai[collateral][maturity][user] - inYDai(collateral, maturity, thisGrab); // TODO: SafeMath shouldn't be needed
            systemDebtYDai[collateral][maturity] =
                systemDebtYDai[collateral][maturity] - inYDai(collateral, maturity, thisGrab); // TODO: SafeMath shouldn't be needed
            if (debtYDai[collateral][maturity][user] == 0){
                returnBond(10);
            }
            if (totalGrabbed == daiAmount) break;
        } // We don't expect hundreds of maturities per dealer
        require(
            totalGrabbed == daiAmount,
            "Dealer: Not enough user debt"
        );
    }

    /// @dev Locks a liquidation bond in gas tokens
    function lockBond(uint256 value) internal {
        if (!_gasToken.transferFrom(msg.sender, address(this), value)) {
            _gasToken.mint(value);
        }
    }

    /// @dev Frees a liquidation bond in gas tokens
    function returnBond(uint256 value) internal {
        _gasToken.transfer(msg.sender, value);
    }
}