pragma solidity ^0.6.2;

import "@hq20/contracts/contracts/math/DecimalMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/ICollateral.sol";
import "./Constants.sol";
import "./YDai.sol"; // TODO: Find how to use an interface


/// @dev Controller manages the state variables for an yDai series
contract Controller is Ownable, Constants {
    using SafeMath for uint256;
    using DecimalMath for uint256;
    using DecimalMath for int256;
    using DecimalMath for uint8;
    using EnumerableSet for EnumerableSet.AddressSet;

    ITreasury internal _treasury;
    IERC20 internal _weth;
    IERC20 internal _dai;
    YDai internal _yDai;
    IVat internal _vat;
    EnumerableSet.AddressSet internal _collaterals;

    mapping(address => mapping(address => uint256)) internal posted; // User/Collateral/Tokens
    mapping(address => mapping(address => uint256)) internal debt; // User/Collateral/Dai

    uint256 public stability; // accumulator (for stability fee) at maturity in ray units
    uint256 public collateralization; // accumulator (for stability fee) at maturity in ray units

    constructor (address treasury_, address yDai_/*, address daiOracle_*/) public {
        _treasury = ITreasury(treasury_);
        _yDai = YDai(yDai_);
        // _daiOracle = IOracle(daiOracle_);
    }

    modifier acceptedCollateral(address collateral) {
        require(
            _collaterals.contains(collateral),
            "Controller: Unknown collateral"
        );
        _;
    }

    function addCollateral(address collateral) public onlyOwner {
        require(
            _collaterals.add(collateral),
            "Controller: Collateral already exists"
        );
    }

    /// @dev Collateral not in use for debt
    //
    //                       debtOf(user)(wad)
    // posted[user](wad) - -----------------------
    //                       daiOracle.get()(ray)
    //
    function unlockedOf(address collateral, address user) public view acceptedCollateral(collateral) returns (uint256) {
        // This is actually collateral/dai price * collateralizationRatio in ray
        uint256 collateralizationMultiplier = ICollateral(collateral).multiplier();
        uint256 locked = debtOf(collateral, user).muld(collateralizationMultiplier, ray);
        if (locked > posted[collateral][user]) return 0; // Unlikely
        return posted[collateral][user].sub(locked);
    }

    /// @dev Return debt in underlying of an user
    //
    //                        rate_now
    // debt_now = debt_mat * ----------
    //                        rate_mat
    //
    function debtOf(address collateral, address user) public view acceptedCollateral(collateral) returns (uint256) {
        if (_yDai.isMature()){
            (, uint256 rate,,,) = _vat.ilks("ETH-A");
            return debt[collateral][user].muld(rate.divd(_yDai.maturityRate(), ray), ray);
        } else {
            return debt[collateral][user];
        }
    }

    /// @dev Moves Eth collateral from user into Treasury controlled Maker Eth vault
    // user --- Weth ---> us
    function post(address collateral, address user, uint256 amount) public acceptedCollateral(collateral) {
        posted[collateral][user] = posted[collateral][user].add(amount);
        // Only for WETH
        _treasury.post(user, amount);
        // For Chai, if treasury has debt, unwrap, repay, and record chi for user.
    }

    /// @dev Moves Eth collateral from Treasury controlled Maker Eth vault back to user
    // us --- Weth ---> user
    function withdraw(address collateral, address user, uint256 amount) public acceptedCollateral(collateral) {
        require(
            unlockedOf(collateral, user) >= amount,
            "Accounts: Free more collateral"
        );
        posted[collateral][user] = posted[collateral][user].sub(amount); // Will revert if not enough posted
        // Only for WETH
        _treasury.withdraw(user, amount);
        // For Chai, if controller has not enough Chai, retrieve chi for user, borrow dai and wrap.
    }

    // ---------- Manage Dai/yDai ----------

    /// @dev Mint yTokens by locking its market value in collateral. Debt is recorded in the vault.
    //
    // posted[user](wad) >= (debt[user](wad)) * amount (wad)) * collateralization (ray)
    //
    // us --- yDai ---> user
    // debt++
    function borrow(address collateral, address user, uint256 amount) public acceptedCollateral(collateral) {
        require(
            _yDai.isMature() != true,
            "Accounts: No mature borrow"
        );
        uint256 collateralizationMultiplier = ICollateral(collateral).multiplier();
        require(
            posted[collateral][user] >= (debtOf(collateral, user).add(amount)).muld(collateralizationMultiplier, ray),
            "Accounts: Post more collateral"
        );
        debt[collateral][user] = debt[collateral][user].add(amount); // TODO: Check collateralization ratio
        _yDai.mint(user, amount);
    }

    /// @dev Moves Dai from user into Treasury controlled Maker Dai vault
    //                                                  debt_maturity
    // debt_discounted = debt_nominal - repay_amount * ---------------
    //                                                  debt_nominal
    //
    // user --- Dai ---> us
    // debt--
    function repay(address collateral, address user, uint256 amount) public acceptedCollateral(collateral) {
        uint256 debtProportion = debt[collateral][user].mul(ray.unit()).divd(debtOf(collateral, user).mul(ray.unit()), ray);
        debt[collateral][user] = debt[collateral][user].sub(amount.muld(debtProportion, ray)); // Will revert if not enough debt
        _treasury.repay(user, amount);
    }

    /// @dev Mint yTokens by posting an equal amount of underlying.
    // user --- Dai  ---> us
    // us   --- yDai ---> user
    function mint(address user, uint256 amount) public {
        _treasury.repay(user, amount);
        _yDai.mint(user, amount);
    }

    /// @dev Burn yTokens and return an equal amount of underlying.
    // user --- yDai ---> us
    // us   --- Dai  ---> user
    function redeem(address user, uint256 amount) public returns (bool) {
        require(
            _yDai.isMature(),
            "Accounts: Only mature redeem"
        );
        _yDai.burn(user, amount);
        _treasury.disburse(user, amount);
    }
}