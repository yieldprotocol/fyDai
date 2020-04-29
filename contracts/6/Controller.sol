pragma solidity ^0.6.2;

import "@hq20/contracts/contracts/math/DecimalMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IYDai.sol";
import "./Constants.sol";


/// @dev Controller manages the state variables for an yDai series
contract Controller is Ownable, Constants {
    using DecimalMath for uint256;
    using DecimalMath for int256;
    using DecimalMath for uint8;

    ITreasury internal _treasury;
    IERC20 internal _weth;
    IERC20 internal _dai;
    IYDai internal _yDai;
    IOracle internal _daiOracle;

    mapping(address => bool) internal validCollateral;
    mapping(address => mapping(address => uint256)) internal posted; // In WETH
    mapping(address => mapping(address => uint256)) internal debt; // In DAI

    event Matured(uint256 rate, uint256 chi);

    bool public isMature;
    uint256 public maturity;
    uint256 public maturityChi;  // accumulator (for dsr) at maturity in ray units
    uint256 public maturityRate; // accumulator (for stability fee) at maturity in ray units

    uint256 public stability; // accumulator (for stability fee) at maturity in ray units
    uint256 public collateralization; // accumulator (for stability fee) at maturity in ray units
    /// @dev modifier to check validity before running function
    modifier check(address collateral) {
        require(
            validCollateral[collateral] == true,
            "Accounts: Invalid collateral"
        );
        _;
    }
    /** 
    constructor (
        address treasury_,
        address weth_,
        address dai_,
        address yDai_,
        address daiOracle_
        ) public {
        _treasury = ITreasury(treasury_);
        _weth = IERC20(weth_);
        _dai = IERC20(dai_);
        _yDai = IYDai(yDai_);
        _daiOracle = IOracle(daiOracle_);
        validCollateral[weth_] = true;
    }
    */
    /**
    /// @dev add liquidity provider token as collateral
    function addLPCollateral(address collateral) public onlyOwner {
        validCollateral[collateral] = true;
    }
    */

    /**
    /// @dev Collateral not in use for debt
    ///
    ///                       debtOf(user)(wad)
    /// posted[user](wad) - -----------------------
    ///                       daiOracle.get()(ray)
    ///
    function unlockedOf(address collateral, address user) public view returns (uint256) {
        //uint256 locked = debtOf(collateral, user).divd(_daiOracle.get(), ray);
        uint256 blue = posted[collateral][user].sub(locked);
        //if (locked > posted[collateral][user]) return 0; // Unlikely
        return posted[collateral][user].sub(locked);
    }
    

    /// @dev Return debt in underlying of an user
    ///
    ///                        rate_now
    /// debt_now = debt_mat * ----------
    ///                        rate_mat
    ///
    function debtOf(address collateral, address user) public view returns (uint256) {
        uint256 blue = posted[collateral][user].sub(locked);
        if (_yDai.isMature){
            (, uint256 rate,,,) = vat.ilks("ETH-A");
            return debt[collateral][user].muld(rate.divd(_yDai.maturityRate, ray), ray);
        } else {
            return debt[collateral][user];
        }
    }
    */

    /** 
    /// @dev Moves Eth collateral from user into Treasury controlled Maker Eth vault
    /// user --- Weth ---> us
    function post(address collateral, address user, uint256 amount) public check(collateral) {
        posted[collateral][user] = posted[collateral][user].add(amount);
        _treasury.post(user, amount);
    }

    /// @dev Moves Eth collateral from Treasury controlled Maker Eth vault back to user
    /// us --- Weth ---> user
    function withdraw(address collateral, address user, uint256 amount) public {
        require(
            unlockedOf(user) >= amount,
            "Accounts: Free more collateral"
        );
        posted[collateral][user] = posted[collateral][user].sub(amount); // Will revert if not enough posted
        _treasury.withdraw(user, amount);
    }

    // ---------- Manage Dai/yDai ----------

    /// @dev Mint yTokens by locking its market value in collateral. Debt is recorded in the vault.
    ///
    /// posted[user](wad) >= (debt[user](wad)) * amount (wad)) * collateralization (ray)
    ///
    /// us --- yDai ---> user
    /// debt++
    function borrow(address collateral, address user, uint256 amount) public {
        require(
            _yDai.isMature != true,
            "Accounts: No mature borrow"
        );
        require(
            posted[collateral][user] >= (debtOf(user).add(amount)).muld(collateralization, ray),
            "Accounts: Post more collateral"
        );
        debt[collateral][user] = debt[collateral][user].add(amount); // TODO: Check collateralization ratio
        _treasury.mint(user, amount);
    }

    /// @dev Moves Dai from user into Treasury controlled Maker Dai vault
    ///                                                  debt_maturity
    /// debt_discounted = debt_nominal - repay_amount * ---------------
    ///                                                  debt_nominal
    ///
    /// user --- Dai ---> us
    /// debt--
    function repay(address collateral, address user, uint256 amount) public {
        uint256 debtProportion = debt[collateral][user].mul(ray.unit()).divd(debtOf(user).mul(ray.unit()), ray);
        // Will revert if not enough debt
        debt[collateral][user] = debt[collateral][user].sub(amount.muld(debtProportion, ray));
        _treasury.repay(user, amount);
    }
    
    /// @dev Mature yDai and capture maturity data
    function mature() public {
        require(
            // solium-disable-next-line security/no-block-members
            now > maturity,
            "YDai: Too early to mature"
        );
        (, maturityRate,,,) = vat.ilks("ETH-A"); // Retrieve the MakerDAO DSR
        maturityRate = Math.max(maturityRate, ray.unit()); // Floor it at 1.0
        maturityChi = pot.chi();
        isMature = true;
        emit Matured(maturityRate, maturityChi);
    }



    /// @dev Mint yTokens by posting an equal amount of underlying.
    /// user --- Dai  ---> us
    /// us   --- yDai ---> user
    function mint(address collateral, address user, uint256 amount) public {
        _treasury.repay(user, amount);
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
        _treasure.disburse(user, amount);
    }
    */
}