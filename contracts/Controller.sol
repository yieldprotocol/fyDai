pragma solidity ^0.6.2;

import "@hq20/contracts/contracts/math/DecimalMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IOracle.sol";
import "./Constants.sol";


/// @dev Controller manages the state variables for an yDai series
contract Controller is Ownable, Constants {
    using DecimalMath for uint256;
    using DecimalMath for int256;
    using DecimalMath for uint8;

    IVault internal _wethVault;
    IVault internal _daiVault;
    IERC20 internal _weth;
    IERC20 internal _dai;
    IYDai internal _yDai;
    IOracle internal _daiOracle;

    mapping(address => uint256) internal posted; // In WETH
    mapping(address => uint256) internal debt; // In DAI

    uint256 public stability; // accumulator (for stability fee) at maturity in ray units
    uint256 public collateralization; // accumulator (for stability fee) at maturity in ray units

    constructor (address treasury_, address yDai_, address daiOracle_) public {
        _treasury = ITreasury(treasury_);
        _yDai = IYDai(yDai_);
        _daiOracle = IOracle(daiOracle_);
    }

    /// @dev Collateral not in use for debt
    ///
    ///                       debtOf(user)(wad)
    /// posted[user](wad) - -----------------------
    ///                       daiOracle.get()(ray)
    ///
    function unlockedOf(address user) public view returns (uint256) {
        uint256 locked = debtOf(user).divd(_daiOracle.get(), ray);
        if (locked > posted[user]) return 0; // Unlikely
        return posted[user].sub(locked);
    }

    /// @dev Return debt in underlying of an user
    ///
    ///                        rate_now
    /// debt_now = debt_mat * ----------
    ///                        rate_mat
    ///
    function debtOf(address user) public view returns (uint256) {
        if (_yDai.isMature){
            (, uint256 rate,,,) = vat.ilks("ETH-A");
            return debt[user].muld(rate.divd(_yDai.maturityRate, ray), ray);
        } else {
            return debt[user];
        }
    }

    /// @dev Moves Eth collateral from user into Treasury controlled Maker Eth vault
    /// user --- Weth ---> us
    function post(address user, uint256 amount) public {
        posted[user] = posted[user].add(amount);
        _wethVault.push(user, amount);
    }

    /// @dev Moves Eth collateral from Treasury controlled Maker Eth vault back to user
    /// us --- Weth ---> user
    function withdraw(address user, uint256 amount) public {
        require(
            unlockedOf(user) >= amount,
            "Accounts: Free more collateral"
        )
        posted[user] = posted[user].sub(amount); // Will revert if not enough posted
        _wethVault.pull(user, amount);
    }

    // ---------- Manage Dai/yDai ----------

    /// @dev Mint yTokens by locking its market value in collateral. Debt is recorded in the vault.
    ///
    /// posted[user](wad) >= (debt[user](wad)) * amount (wad)) * collateralization (ray)
    ///
    /// us --- yDai ---> user
    /// debt++
    function borrow(address user, uint256 amount) public {
        require(
            _yDai.isMature != true,
            "Accounts: No mature borrow"
        );
        require(
            posted[user] >= (debtOf(user).add(amount)).muld(collateralization, ray),
            "Accounts: Post more collateral"
        )
        debt[user] = debt[user].add(amount); // TODO: Check collateralization ratio
        _yDai.mint(user, amount);
    }

    /// @dev Moves Dai from user into Treasury controlled Maker Dai vault
    ///                                                  debt_maturity
    /// debt_discounted = debt_nominal - repay_amount * ---------------
    ///                                                  debt_nominal
    ///
    /// user --- Dai ---> us
    /// debt--
    function repay(address user, uint256 amount) public {
        uint256 debtProportion = debt[user].mul(ray.unit()).divd(debtOf(user).mul(ray.unit()), ray);
        debt[user] = debt[user].sub(amount.muld(debtProportion, ray)); // Will revert if not enough debt
        _daiVault.push(user, amount);
    }

    /// @dev Mint yTokens by posting an equal amount of underlying.
    /// user --- Dai  ---> us
    /// us   --- yDai ---> user
    function mint(address user, uint256 amount) public {
        _daiVault.push(user, amount);
        _yDai.mint(user, amount);
    }

    /// @dev Burn yTokens and return an equal amount of underlying.
    /// user --- yDai ---> us
    /// us   --- Dai  ---> user
    function redeem(address user, uint256 amount) public returns (bool) {
        require(
            _yDai.isMature() == true,
            "Accounts: Only mature redeem"
        );
        _yDai.burn(user, amount);
        _daiVault.pull(user, amount);
    }
}