// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DecimalMath.sol";
import "../interfaces/IVat.sol";
import "../interfaces/IDaiJoin.sol";
import "../interfaces/IGemJoin.sol";
import "../interfaces/IPot.sol";
import "../interfaces/IChai.sol";


interface BackdoorWeth {
    function mint(address, uint) external returns(bool);
    function approve(address, uint) external returns (bool) ;
}

contract Faucet is DecimalMath {

    bytes32 constant WETH = "ETH-A";

    IVat public vat;
    BackdoorWeth public weth;
    IERC20 public dai;
    IDaiJoin public daiJoin;
    IGemJoin public wethJoin;
    IPot public pot;
    IChai public chai;

    /// @dev As part of the constructor:
    /// Treasury allows the `chai` and `wethJoin` contracts to take as many tokens as wanted.
    /// Treasury approves the `daiJoin` and `wethJoin` contracts to move assets in MakerDAO.
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
        vat = IVat(vat_);
        weth = BackdoorWeth(weth_);
        dai = IERC20(dai_);
        daiJoin = IDaiJoin(daiJoin_);
        wethJoin = IGemJoin(wethJoin_);
        pot = IPot(pot_);
        chai = IChai(chai_);
        vat.hope(wethJoin_);
        vat.hope(daiJoin_);

        dai.approve(address(chai), uint256(-1));      // Chai will never cheat on us
        weth.approve(address(wethJoin), uint256(-1)); // WethJoin will never cheat on us
    }

    /// @dev Safe casting from uint256 to int256
    function toInt(uint256 x) internal pure returns(int256) {
        require(
            x <= uint256(type(int256).max),
            "Treasury: Cast overflow"
        );
        return int256(x);
    }

    /// @dev Use the Weth backdoor to obtain Weth
    function getWeth(address to, uint256 amount) public returns (bool) {
        weth.mint(to, amount);
    }

    /// @dev Use the Weth backdoor to obtain Weth, and then use that to borrow Dai
    function getDai(address to, uint256 amount) public returns (bool) {
        (, uint256 rate, uint256 spot,,) = vat.ilks(WETH);
        uint256 ink = divdrup(amount, spot);
        uint256 art = divdrup(amount, rate);

        getWeth(address(this), ink);
        wethJoin.join(address(this), ink);
        vat.frob(
            WETH,
            address(this),
            address(this),
            address(this),
            toInt(ink),
            toInt(art)
        );
        daiJoin.exit(to, amount);
    }

    /// @dev Use the Weth backdoor to obtain Weth, to borrow Dai, and then to exchange it for Chai
    function getChai(address to, uint256 amount) public returns (bool) {
        uint256 daiAmount = muldrup(amount, pot.chi());
        getDai(address(this), daiAmount);
        chai.join(to, daiAmount);
    }
}