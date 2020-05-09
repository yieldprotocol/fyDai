pragma solidity ^0.6.2;

import "@hq20/contracts/contracts/math/DecimalMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IUniswap.sol";
import "./Constants.sol";
import "./YDai.sol"; // TODO: Find how to use an interface

import "@nomiclabs/buidler/console.sol";

/// @dev Controller manages the state variables for an yDai series
contract UniLPController is Ownable, Constants {
    using SafeMath for uint256;
    using DecimalMath for uint256;
    using DecimalMath for int256;
    using DecimalMath for uint8;

    ITreasury internal _treasury;
    IERC20 internal _weth;
    IERC20 internal _collateral;
    IERC20 internal _dai;
    YDai internal _yDai;
    IVat internal _vat;
    IOracle internal _daiOracle;
    IUniswap internal _uniswap;

    mapping(address => uint256) internal posted; // In WETH
    mapping(address => uint256) internal debt; // In DAI

    uint256 public stability; // accumulator (for stability fee) at maturity in ray units
    uint256 public collateralization; // accumulator (for stability fee) at maturity in ray units

    uint256 public two = ray.unit() * 2; 

    constructor (
        address collateral_, 
        address weth_,
        address dai_,
        address treasury_, 
        address yDai_, 
        address daiOracle_,
        address vat_,
        address uniswap_
        ) public {
            _weth = IERC20(weth_);
            _dai  = IERC20(dai_);
            _collateral = IERC20(collateral_);
            _treasury = ITreasury(treasury_);
            _yDai = YDai(yDai_);
            _daiOracle = IOracle(daiOracle_);
            _vat = IVat(vat_);
            _uniswap = IUniswap(uniswap_);
    }
    
    // We should replace this sqrt with the appropriate library version, if any
    function sqrt(uint x) private pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }


    /// @dev minimum to lock for amount of new debt
    //
    //                       amount * totalLPtokens (wad)
    // minLocked =      ----------------------------------------
    //                       2  * √(reserves1 * reserves2)
    //
    function minLocked(uint256 amount) public view returns (uint256) {
        (uint112 _reserve0, uint112 _reserve1,) = _uniswap.getReserves(); 
        uint256 _totalSupply = _uniswap.totalSupply();
        uint256 divisor = 2 * sqrt(uint256(_reserve0)
                    .mul(uint256(_reserve1))); 
        return amount.muld(_totalSupply, wad).divd(divisor, wad);
    }


    /// @dev Collateral not in use for debt
    //
    //                       debtOf(user)(wad) * totalLPtokens (wad)
    // posted[user](wad) - ----------------------------------------
    //                       2  * √(reserves1 * reserves2)
    //
    function unlockedOf(address user) public view returns (uint256) {
        uint256 locked = minLocked(debtOf(user));
        if (locked > posted[user]) return 0; // Unlikely
        return posted[user].sub(locked);
    }

    /// @dev Return debt in underlying of an user
    //
    //                        rate_now
    // debt_now = debt_mat * ----------
    //                        rate_mat
    //
    function debtOf(address user) public view returns (uint256) {
        if (_yDai.isMature()){
            (, uint256 rate,,,) = _vat.ilks("ETH-A");
            return debt[user].muld(rate.divd(_yDai.maturityRate(), ray), ray);
        } else {
            return debt[user];
        }
    }

    /// @dev Moves Eth collateral from user into Treasury controlled Maker Eth vault
    // user --- Weth ---> us
    function post(address user, uint256 amount) public {
        posted[user] = posted[user].add(amount);
        _treasury.post(user, amount);
    }

    /// @dev Moves Eth collateral from Treasury controlled Maker Eth vault back to user
    // us --- Weth ---> user
    function withdraw(address user, uint256 amount) public {
        require(
            unlockedOf(user) >= amount,
            "Accounts: Free more collateral"
        );
        posted[user] = posted[user].sub(amount); // Will revert if not enough posted
        _treasury.withdraw(user, amount);
    }

    // ---------- Manage Dai/yDai ----------

    /// @dev Mint yTokens by locking its market value in collateral. Debt is recorded in the vault.
    //
    // posted[user](wad) >= (debt[user](wad)) * amount (wad)) * collateralization (ray)
    //
    // us --- yDai ---> user
    // debt++
    function borrow(address user, uint256 amount) public {
        require(
            _yDai.isMature() != true,
            "Accounts: No mature borrow"
        );
        require(
            posted[user] >= minLocked(debtOf(user).add(amount)),
            "Accounts: Post more collateral"
        );
        debt[user] = debt[user].add(amount); // TODO: Check collateralization ratio
        _yDai.mint(user, amount);
    }

    /// @dev Moves Dai from user into Treasury controlled Maker Dai vault
    //                                                  debt_maturity
    // debt_discounted = debt_nominal - repay_amount * ---------------
    //                                                  debt_nominal
    //
    // user --- Dai ---> us
    // debt--
    function repay(address user, uint256 amount) public {
        uint256 debtProportion = debt[user].mul(ray.unit()).divd(debtOf(user).mul(ray.unit()), ray);
        debt[user] = debt[user].sub(amount.muld(debtProportion, ray)); // Will revert if not enough debt
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