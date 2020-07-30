// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IVat.sol";
import "./interfaces/IDaiJoin.sol";
import "./interfaces/IGemJoin.sol";
import "./interfaces/IPot.sol";
import "./interfaces/IEnd.sol";
import "./interfaces/IChai.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IController.sol";
import "./interfaces/IYDai.sol";
import "./interfaces/ILiquidations.sol";
import "./helpers/DecimalMath.sol";



/**
 * @dev Unwind allows everyone to recover their assets from the Yield protocol in the event of a MakerDAO shutdown.
 * Unwind also allows to remove any protocol profits at any time to the beneficiary address using `skimWhileLive`.
 * During the unwind process, the system debt to MakerDAO is settled first with `settleTreasury`, extracting all free weth.
 * Once the Treasury is settled, any system savings are converted from Chai to Weth using `cashSavings`.
 * At this point, users can settle their positions using `settle`. The MakerDAO rates will be used to convert all debt and collateral to a Weth payout.
 * Users can also redeem here their yDai for a Weth payout, using `redeem`.
 * Protocol profits can be transferred to the beneficiary also at this point, using `skimDssShutdown`.
 */
contract Unwind is Ownable(), DecimalMath {
    using SafeMath for uint256;

    bytes32 public constant CHAI = "CHAI";
    bytes32 public constant WETH = "ETH-A";

    IVat internal _vat;
    IDaiJoin internal _daiJoin;
    IERC20 internal _weth;
    IGemJoin internal _wethJoin;
    IPot internal _pot;
    IEnd internal _end;
    IChai internal _chai;
    ITreasury internal _treasury;
    IController internal _controller;
    ILiquidations internal _liquidations;

    uint256 public _fix; // Dai to weth price on DSS Unwind
    uint256 public _chi; // Chai to dai price on DSS Unwind

    uint256 internal _treasuryWeth; // Weth that was held by treasury before settling

    bool public settled;
    bool public cashedOut;
    bool public live = true;

    address public beneficiary;

    /// @dev The constructor links to vat, daiJoin, weth, wethJoin, jug, pot, end, chai, treasury, controller and liquidations.
    /// Liquidations should have privileged access to treasury, controller and liquidations using orchestration.
    /// The constructor gives treasury and end permission on unwind's MakerDAO vaults.
    constructor (
        address vat_,
        address daiJoin_,
        address weth_,
        address wethJoin_,
        address pot_,
        address end_,
        address chai_,
        address treasury_,
        address controller_,
        address liquidations_,
        address beneficiary_
    ) public {
        // These could be hardcoded for mainnet deployment.
        _vat = IVat(vat_);
        _daiJoin = IDaiJoin(daiJoin_);
        _weth = IERC20(weth_);
        _wethJoin = IGemJoin(wethJoin_);
        _pot = IPot(pot_);
        _end = IEnd(end_);
        _chai = IChai(chai_);
        _treasury = ITreasury(treasury_);
        _controller = IController(controller_);
        _liquidations = ILiquidations(liquidations_);
        beneficiary = beneficiary_;

        _vat.hope(address(_treasury));
        _vat.hope(address(_end));
    }

    /// @dev max(0, x - y)
    function subFloorZero(uint256 x, uint256 y) public pure returns(uint256) {
        if (y >= x) return 0;
        else return x - y;
    }

    /// @dev Safe casting from uint256 to int256
    function toInt(uint256 x) internal pure returns(int256) {
        require(
            x <= 57896044618658097711785492504343953926634992332820282019728792003956564819967,
            "Treasury: Cast overflow"
        );
        return int256(x);
    }

    /// @dev Disables treasury, controller and liquidations.
    function unwind() public {
        require(
            _end.tag(WETH) != 0,
            "Unwind: MakerDAO not shutting down"
        );
        live = false;
        _treasury.shutdown();
        _controller.shutdown();
        _liquidations.shutdown();
    }

    /// @dev Calculates how much profit is in the system and transfers it to the beneficiary
    function skimWhileLive() public {
        require(
            live == true, // If DSS is not live this method will fail later on.
            "Unwind: Can only skimWhileLive if live"
        );
        require(
            now >= _controller.skimStart(),
            "Unwind: Only after skimStart"
        );

        uint256 chi = _pot.chi();
        (, uint256 rate,,,) = _vat.ilks(WETH);
        // At worst, we would recover no collateral from Liquidations, so we ignore it.

        uint256 profit = _chai.balanceOf(address(_treasury));
        profit = profit.add(_yDaiProfit(chi, rate));
        profit = profit.sub(divd(_treasury.debt(), chi));
        profit = profit.sub(_controller.totalChaiPosted());

        _treasury.pullChai(beneficiary, profit);
    }

    /// @dev Calculates how much profit is in the system and transfers it to the beneficiary
    function skimDssShutdown() public {
        require(settled && cashedOut, "Unwind: Not ready");

        uint256 chi = _pot.chi();
        (, uint256 rate,,,) = _vat.ilks(WETH);
        (uint256 liquidationsCollateral, uint256 liquidationsDebt) = _liquidations.totals();
        // TODO: Test profit skimming from liquidations

        uint256 profit = _weth.balanceOf(address(this));

        profit = profit.add(liquidationsCollateral);
        profit = profit.add(muld(muld(_yDaiProfit(chi, rate), chi), _fix));
        profit = profit.sub(muld(liquidationsDebt, _fix));
        profit = profit.sub(_treasuryWeth);
        profit = profit.sub(muld(muld(_controller.totalChaiPosted(), chi), _fix));

        require(_weth.transfer(beneficiary, profit));
    }

    /// @dev Returns the profit accummulated in the system due to yDai supply and debt, in chai.
    /// Chi and rate are passed on as parameters to avoid multiple calls that retrieve the same values.
    /// @param chi The chi value from MakerDAO
    /// @param rate The rate value from MakerDAO
    function _yDaiProfit(uint256 chi, uint256 rate) internal view returns (uint256) {
        uint256 profit;

        (IYDai[] memory series, uint256[] memory maturities) = _controller.allSeries();
        for (uint256 i = 0; i < series.length; i += 1) {
            uint256 maturity = maturities[i];
            IYDai yDai = series[i];
            profit = profit.add(getProfit(yDai, maturity, chi, rate));
        }

        return profit;
    }

    /// @dev Returns the profit accumulated for a specific yDai token
    // NB: this funciton is required due to `Stack Too Deep` errors.
    function getProfit(IYDai yDai, uint256 maturity, uint256 chi, uint256 rate) private view returns (uint256) {
        uint256 profit;

        uint256 chi0;
        uint256 rate0;
        if (yDai.isMature()){
            chi0 = yDai.chi0();
            rate0 = yDai.rate0();
        } else {
            chi0 = chi;
            rate0 = rate;
        }

        profit = profit.add(
            divd(
                muld(
                    _controller.totalDebtYDai(WETH, maturity),
                    Math.max(UNIT, divd(rate, rate0)) // rate growth since maturity, floored at 1.0
                ),                                    // muld(yDaiDebt, rateGrowth) - Convert Weth collateralized YDai debt to Dai debt
                chi                                   // divd(daiDebt, chi) - Convert Dai debt to Chai debt
            )
        );
        profit = profit.add(
            divd(
                _controller.totalDebtYDai(CHAI, maturity),
                chi0                                  // divd(yDaiDebt, chi0) - Convert Chai collateralized YDai debt to Chai debt
            )
        );
        profit = profit.sub(divd(yDai.totalSupply(), chi0)); // divd(yDai, chi0) - Convert YDai to Chai

        return profit;
    }

    /// @dev Settle system debt in MakerDAO and free remaining collateral.
    function settleTreasury() public {
        require(
            live == false,
            "Unwind: Unwind first"
        );
        (uint256 ink, uint256 art) = _vat.urns(WETH, address(_treasury));
        _treasuryWeth = ink;                            // We will need this to skim profits
        _vat.fork(                                      // Take the treasury vault
            WETH,
            address(_treasury),
            address(this),
            toInt(ink),
            toInt(art)
        );
        _end.skim(WETH, address(this));                // Settle debts
        _end.free(WETH);                               // Free collateral
        uint256 gem = _vat.gem(WETH, address(this));   // Find out how much collateral we have now
        _wethJoin.exit(address(this), gem);            // Take collateral out
        settled = true;
    }

    /// @dev Put all chai savings in MakerDAO and exchange them for weth
    function cashSavings() public {
        require(
            _end.tag(WETH) != 0,
            "Unwind: End.sol not caged"
        );
        require(
            _end.fix(WETH) != 0,
            "Unwind: End.sol not ready"
        );
        uint256 daiTokens = _chai.dai(address(_treasury));   // Find out how much is the chai worth
        _chai.draw(address(_treasury), _treasury.savings()); // Get the chai as dai
        _daiJoin.join(address(this), daiTokens);             // Put the dai into MakerDAO
        _end.pack(daiTokens);                                // Into End.sol, more exactly
        _end.cash(WETH, daiTokens);                          // Exchange the dai for weth
        uint256 gem = _vat.gem(WETH, address(this));         // Find out how much collateral we have now
        _wethJoin.exit(address(this), gem);                  // Take collateral out
        cashedOut = true;

        _fix = _end.fix(WETH);
        _chi = _pot.chi();
    }

    /// @dev Settles a series position in Controller, and then returns any remaining collateral as weth using the unwind Dai to Weth price.
    /// @param collateral Valid collateral type.
    /// @param user User vault to settle, and wallet to receive the corresponding weth.
    function settle(bytes32 collateral, address user) public {
        require(settled && cashedOut, "Unwind: Not ready");

        (uint256 tokens, uint256 debt) = _controller.erase(collateral, user);

        uint256 remainder;
        if (collateral == WETH) {
            remainder = subFloorZero(tokens, muld(debt, _fix));
        } else if (collateral == CHAI) {
            remainder = muld(subFloorZero(muld(tokens, _chi), debt), _fix);
        }
        require(_weth.transfer(user, remainder));
    }

    /// @dev Redeems YDai for weth. YDai.redeem won't work if MakerDAO is in shutdown.
    /// yDai holder must call yDai.approve before calling this function.
    /// @param maturity Maturity of an added series
    /// @param user Wallet containing the yDai to burn.
    /// @param yDaiAmount Amount of yDai to burn.
    function redeem(uint256 maturity, address user, uint256 yDaiAmount) public {
        require(settled && cashedOut, "Unwind: Not ready");
        IYDai yDai = _controller.series(maturity);
        yDai.burn(user, yDaiAmount);
        require(
            _weth.transfer(
                user,
                muld(muld(yDaiAmount, yDai.chiGrowth()), _fix)
            )
        );
    }
}
