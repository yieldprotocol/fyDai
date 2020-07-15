pragma solidity ^0.6.10;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../helpers/DecimalMath.sol";
import "../interfaces/IVat.sol";
import "../interfaces/IGemJoin.sol";
import "../interfaces/IDaiJoin.sol";
import "../interfaces/IPot.sol";
import "../interfaces/IChai.sol";
import "../interfaces/IYDai.sol";
import "../interfaces/IDealer.sol";
import "../interfaces/IMarket.sol";
import "../interfaces/IFlashMinter.sol";
import "@nomiclabs/buidler/console.sol";


/// @dev The Market contract exchanges Dai for yDai at a price defined by a specific formula.
contract Splitter is IFlashMinter, DecimalMath {

    bytes32 public constant WETH = "ETH-A";
    bool constant public MTY = true;
    bool constant public YTM = false;

    IVat public vat;
    IERC20 public weth;
    IERC20 public dai;
    IGemJoin public wethJoin;
    IDaiJoin public daiJoin;
    IPot public pot;
    IChai public chai;
    IYDai public yDai;
    IDealer public dealer;
    IMarket public market;

    constructor(
        address vat_,
        address weth_,
        address dai_,
        address wethJoin_,
        address daiJoin_,
        address pot_,
        address chai_,
        address treasury_,
        address yDai_,
        address dealer_,
        address market_
    ) public {
        vat = IVat(vat_);
        weth = IERC20(weth_);
        dai = IERC20(dai_);
        wethJoin = IGemJoin(wethJoin_);
        daiJoin = IDaiJoin(daiJoin_);
        pot = IPot(pot_);
        chai = IChai(chai_);
        yDai = IYDai(yDai_);
        dealer = IDealer(dealer_);
        market = IMarket(market_);

        vat.hope(daiJoin_);
        vat.hope(wethJoin_);

        chai.approve(market_, uint256(-1));
        yDai.approve(market_, uint256(-1));
        dai.approve(daiJoin_, uint(-1));
        weth.approve(wethJoin_, uint(-1));
        weth.approve(treasury_, uint(-1));
    }

    /// @dev Safe casting from uint256 to int256
    function toInt(uint256 x) internal pure returns(int256) {
        require(
            x <= 57896044618658097711785492504343953926634992332820282019728792003956564819967,
            "Treasury: Cast overflow"
        );
        return int256(x);
    }

    function makerToYield(address user, uint256 yDaiAmount, uint256 wethAmount, uint256 daiAmount) public {
        // The user specifies the yDai he wants to mint to cover his maker debt, the weth to be passed on as collateral, and the dai debt to move
        // Flash mint the yDai
        yDai.flashMint(user, yDaiAmount, abi.encode(MTY, wethAmount, daiAmount));
    }

    function yieldToMaker(address user, uint256 yDaiAmount, uint256 wethAmount) public {
        // The user specifies the yDai he wants to move, and the weth to be passed on as collateral
        // Flash mint the yDai
        yDai.flashMint( user, yDaiAmount, abi.encode(YTM, wethAmount, 0)); // The daiAmount encoded is ignored
    }

    function executeOnFlashMint(address user, uint256 yDaiAmount, bytes calldata data) external override {
        (bool direction, uint256 wethAmount, uint256 daiAmount) = abi.decode(data, (bool, uint256, uint256));
        if(direction == MTY) _makerToYield(user, yDaiAmount, wethAmount, daiAmount); // TODO: Consider parameter order
        if(direction == YTM) _yieldToMaker(user, yDaiAmount, wethAmount, daiAmount); // TODO: Consider parameter order
    }

    /// @dev Minimum weth needed to collateralize an amount of dai in MakerDAO
    function wethForDai(uint256 daiAmount) public view returns (uint256) {
        (,, uint256 spot,,) = vat.ilks("ETH-A");
        return divd(daiAmount, spot);
    }

    /// @dev Minimum weth needed to collateralize an amount of yDai in Yield. Yes, it's the same formula.
    function wethForYDai(uint256 yDaiAmount) public view returns (uint256) {
        (,, uint256 spot,,) = vat.ilks("ETH-A");
        return divd(yDaiAmount, spot);
    }

    function yDaiForDai(uint256 daiAmount) public view returns (uint256) {
        uint256 chi = pot.chi(); // Being just a preview, we don't call drip()
        uint256 chaiToBuy = divdrup(daiAmount, chi);
        return market.buyChaiPreview(uint128(chaiToBuy));
    }

    /// @dev Internal function to transfer debt and collateral from MakerDAO to Yield
    /// @param yDaiAmount yDai that was flash-minted, needs to be high enough to buy the chai in the market
    /// @param wethAmount weth to move from MakerDAO to Yield. Needs to be high enough to collateralize the dai debt in Yield,
    /// and low enough to make sure that debt left in MakerDAO is also collateralized.
    /// @param daiAmount dai debt to move from MakerDAO to Yield. Denominated in Dai (= art * rate)
    function _makerToYield(address user, uint256 yDaiAmount, uint256 wethAmount, uint256 daiAmount) internal {
        // Calculate how much dai should be repaid as the minimum between daiAmount and the existing user debt
        (uint256 ink, uint256 art) = vat.urns(WETH, user);
        (, uint256 rate,,,) = vat.ilks("ETH-A");
        require(
            daiAmount >= muld(art, rate),
            "Splitter: Not enough debt in Maker"
        );
        // Calculate how much chai is the daiAmount equivalent to
        // uint256 chi = (now > pot.rho()) ? pot.drip() : pot.chi();
        uint256 chaiToBuy = divdrup(
            daiAmount,
            (now > pot.rho()) ? pot.drip() : pot.chi()
        );
        // Market will take as much YDai as needed, if available. Splitter will hold the chai temporarily
        uint256 yDaiSold = market.buyChai(user, address(this), uint128(chaiToBuy)); // TODO: Consider SafeCast
        uint256 wethToWithdraw = Math.max(wethForDai(daiAmount), wethForYDai(yDaiSold));
        require(
            wethToWithdraw >= wethAmount,
            "Splitter: Not enough collateral provided"
        );
        require(
            wethToWithdraw >= ink,
            "Splitter: Not enough collateral in Maker"
        );
        { // Working around the stack too deep issue
            // Unpack the Chai into Dai
            chai.exit(address(this), chai.balanceOf(address(this)));
            // Put the Dai in Maker
            // TODO: daiJoin.hope(splitter.address, { from: user });
            daiJoin.join(user, daiAmount);
            // Pay the debt in Maker
            // Needs vat.hope(splitter.address, { from: user });
            vat.frob(
                "ETH-A",
                user,
                user,
                user,
                -toInt(wethToWithdraw),         // Weth collateral to add
                -toInt(divd(daiAmount, rate))  // Dai debt to add
            );
            // Remove the collateral from Maker
            vat.flux("ETH-A", user, address(this), wethToWithdraw);
            wethJoin.exit(address(this), wethToWithdraw); // Splitter will hold the weth temporarily
            // Add the collateral to Yield
            dealer.post(WETH, address(this), user, wethToWithdraw);
            // Borrow the Dai
            console.log(yDaiSold);
            dealer.borrow(WETH, yDai.maturity(), user, user, yDaiSold);
        }
    }

    function _yieldToMaker(address user, uint256 yDaiAmount, uint256 wethAmount, uint256 daiAmount) internal {
        // Pay the Yield debt
        dealer.repayYDai(WETH, yDai.maturity(), user, user, yDaiAmount); // repayYDai wil only take what is needed
        // Withdraw the collateral from Yield
        // TODO: dealer.addDelegate(splitter.address, { from: user });
        dealer.withdraw(WETH, user, address(this), wethAmount);
        // Post the collateral to Maker
        // TODO: wethJoin.hope(splitter.address, { from: user });
        wethJoin.join(user, wethAmount);
        // Borrow the Dai from Maker
        (, uint256 rate,,,) = vat.ilks("ETH-A");            // Retrieve the MakerDAO stability fee for Weth
        // TODO: vat.hope(splitter.address, { from: user });
        vat.frob(
            "ETH-A",
            user,
            user,
            user,
            toInt(wethAmount),                           // Weth collateral to add
            toInt(divd(daiAmount, rate))  // Dai debt to remove
        );
        vat.move(user, address(this), daiAmount);
        daiJoin.exit(address(this), daiAmount); // Splitter will hold the dai temporarily
        // Wrap the Dai into Chai
        chai.join(address(this), dai.balanceOf(address(this)));
        // Sell the Chai for YDai at Market - It should make up for what was taken with repayYdai
        // Splitter will hold the chai temporarily - TODO: Consider SafeCast
        market.sellChai(address(this), address(this), uint128(chai.balanceOf(address(this))));
    }
}