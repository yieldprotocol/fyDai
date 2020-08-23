// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

import "../interfaces/IController.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IWeth.sol";

import "../interfaces/IVat.sol";
import "../interfaces/IPot.sol";
import "../interfaces/IPool.sol";
import "../interfaces/IYDai.sol";
import "../interfaces/IChai.sol";
import "../helpers/DecimalMath.sol";

library SafeCast {
    /// @dev Safe casting from uint256 to uint128
    function toUint128(uint256 x) internal pure returns(uint128) {
        require(
            x <= type(uint128).max,
            "Pool: Cast overflow"
        );
        return uint128(x);
    }
}

contract YieldProxy is DecimalMath {
    using SafeCast for uint256;

    IController public controller;

    IERC20 public dai;
    IChai public chai;
    IWeth public weth;

    bytes32 public constant CHAI = "CHAI";
    bytes32 public constant WETH = "ETH-A";

    constructor(address controller_) public {
        controller = IController(controller_);
        ITreasury treasury = controller.treasury();

        weth = treasury.weth();
        dai = treasury.dai();
        chai = treasury.chai();

        // Approve all the coins
        dai.approve(address(treasury), uint(-1));
        chai.approve(address(treasury), uint(-1));
        weth.approve(address(treasury), uint(-1));
    }

    /// @dev The WETH9 contract will send ether to EthProxy on `weth.withdraw` using this function.
    receive() external payable { }

    /// Max approval everywhere and adds the proxy as a delegate
    function authorize() public {
        ITreasury treasury = controller.treasury();
        dai.approve(address(treasury), uint(-1));
        chai.approve(address(treasury), uint(-1));
        weth.approve(address(treasury), uint(-1));
        // controller.addDelegate();
    }

    ///////////// EthProxy

    /// @dev Users use `post` in EthProxy to post ETH to the Controller, which will be converted to Weth here.
    /// @param to Yield Vault to deposit collateral in.
    /// @param amount Amount of collateral to move.
    function post(address to, uint256 amount)
        public payable {
        weth.deposit{ value: amount }();
        controller.post(WETH, address(this), to, amount);
    }

    /// @dev Users wishing to withdraw their Weth as ETH from the Controller should use this function.
    /// Users must have called `controller.addDelegate(ethProxy.address)` to authorize EthProxy to act in their behalf.
    /// @param to Wallet to send Eth to.
    /// @param amount Amount of weth to move.
    function withdraw(address payable to, uint256 amount)
        public {
        controller.withdraw(WETH, msg.sender, address(this), amount);
        weth.withdraw(amount);
        to.transfer(amount);
    }

    //// Liquidity Proxy

    /// @dev Mints liquidity with provided Dai by borrowing yDai with some of the Dai.
    /// Caller must have approved the proxy using`controller.addDelegate(liquidityProxy)` and `pool.addDelegate(liquidityProxy)`
    /// Caller must have approved the dai transfer with `dai.approve(daiUsed)`
    /// @param daiUsed amount of Dai to use to mint liquidity. 
    /// @param maxYDai maximum amount of yDai to be borrowed to mint liquidity. 
    /// @return The amount of liquidity tokens minted.  
    function addLiquidity(IPool pool, uint256 daiUsed, uint256 maxYDai) external returns (uint256)
    {
        IYDai yDai = pool.yDai();
        require(yDai.isMature() != true, "LiquidityProxy: Only before maturity");
        require(dai.transferFrom(msg.sender, address(this), daiUsed), "LiquidityProxy: Transfer Failed");

        // calculate needed yDai
        uint256 daiReserves = dai.balanceOf(address(pool));
        uint256 yDaiReserves = yDai.balanceOf(address(pool));
        uint256 daiToAdd = daiUsed.mul(daiReserves).div(yDaiReserves.add(daiReserves));
        uint256 daiToConvert = daiUsed.sub(daiToAdd);
        require(
            daiToConvert <= maxYDai,
            "LiquidityProxy: maxYDai exceeded"
        ); // 1 Dai == 1 yDai

        // convert dai to chai and borrow needed yDai
        chai.join(address(this), daiToConvert);
        // look at the balance of chai in dai to avoid rounding issues
        uint256 toBorrow = chai.dai(address(this));
        controller.post(CHAI, address(this), msg.sender, chai.balanceOf(address(this)));
        controller.borrow(CHAI, yDai.maturity(), msg.sender, address(this), toBorrow);
        
        // mint liquidity tokens
        return pool.mint(address(this), msg.sender, daiToAdd);
    }

    /// @dev Burns tokens and repays yDai debt. Buys needed yDai or sells any excess, and all Dai is returned.
    /// Caller must have approved the proxy using`controller.addDelegate(liquidityProxy)` and `pool.addDelegate(liquidityProxy)`
    /// Caller must have approved the liquidity burn with `pool.approve(poolTokens)`
    /// @param poolTokens amount of pool tokens to burn. 
    /// @param minimumDai minimum amount of Dai to be bought with yDai when burning. 
    function removeLiquidityEarly(IPool pool, uint256 poolTokens, uint256 minimumDai) external {
        IYDai yDai = pool.yDai();
        (uint256 daiObtained, uint256 yDaiObtained) = pool.burn(msg.sender, address(this), poolTokens);
        repayDebt(yDai, daiObtained, yDaiObtained);
        uint256 remainingYDai = yDai.balanceOf(address(this));
        if (remainingYDai > 0) {
            require(
                pool.sellYDai(address(this), address(this), uint128(remainingYDai)) >= minimumDai,
                "LiquidityProxy: minimumDai not reached"
            );
        }
        withdrawAssets(yDai);
    }

    /// @dev Burns tokens and repays yDai debt after Maturity. 
    /// Caller must have approved the proxy using`controller.addDelegate(liquidityProxy)`
    /// Caller must have approved the liquidity burn with `pool.approve(poolTokens)`
    /// @param poolTokens amount of pool tokens to burn.
    function removeLiquidityMature(IPool pool, uint256 poolTokens) external {
        IYDai yDai = pool.yDai();
        (uint256 daiObtained, uint256 yDaiObtained) = pool.burn(msg.sender, address(this), poolTokens);
        if (yDaiObtained > 0) yDai.redeem(address(this), address(this), yDaiObtained);
        repayDebt(yDai, daiObtained, 0);
        withdrawAssets(yDai);
    }

    /// @dev Repay debt from the caller using the dai and yDai supplied
    /// @param daiAvailable amount of dai to use for repayments.
    /// @param yDaiAvailable amount of yDai to use for repayments.
    function repayDebt(IYDai yDai, uint256 daiAvailable, uint256 yDaiAvailable) internal {
        uint256 maturity = yDai.maturity();
        if (yDaiAvailable > 0 && controller.debtYDai(CHAI, maturity, msg.sender) > 0) {
            controller.repayYDai(CHAI, maturity, address(this), msg.sender, yDaiAvailable);
        }
        if (daiAvailable > 0 && controller.debtYDai(CHAI, maturity, msg.sender) > 0) {
            controller.repayDai(CHAI, maturity, address(this), msg.sender, daiAvailable);
        }
    }

    /// @dev Return to caller all posted chai if there is no debt, converted to dai, plus any dai remaining in the contract.
    function withdrawAssets(IYDai yDai) internal {
        if (controller.debtYDai(CHAI, yDai.maturity(), msg.sender) == 0) {
            controller.withdraw(CHAI, msg.sender, address(this), controller.posted(CHAI, msg.sender));
            chai.exit(address(this), chai.balanceOf(address(this)));
        }
        require(dai.transfer(msg.sender, dai.balanceOf(address(this))), "LiquidityProxy: Dai Transfer Failed");
    }

    /// DAI Proxy

    /// @dev Borrow yDai from Controller and sell it immediately for Dai, for a maximum yDai debt.
    /// Must have approved the operator with `controller.addDelegate(daiProxy.address)`.
    /// @param collateral Valid collateral type.
    /// @param maturity Maturity of an added series
    /// @param to Wallet to send the resulting Dai to.
    /// @param maximumYDai Maximum amount of YDai to borrow.
    /// @param daiToBorrow Exact amount of Dai that should be obtained.
    function borrowDaiForMaximumYDai(
        IPool pool,
        bytes32 collateral,
        uint256 maturity,
        address to,
        uint256 maximumYDai,
        uint256 daiToBorrow
    )
        public
        returns (uint256)
    {
        uint256 yDaiToBorrow = pool.buyDaiPreview(daiToBorrow.toUint128());
        require (yDaiToBorrow <= maximumYDai, "DaiProxy: Too much yDai required");

        // The collateral for this borrow needs to have been posted beforehand
        controller.borrow(collateral, maturity, msg.sender, address(this), yDaiToBorrow);
        pool.buyDai(address(this), to, daiToBorrow.toUint128());

        return yDaiToBorrow;
    }

    /// @dev Borrow yDai from Controller and sell it immediately for Dai, if a minimum amount of Dai can be obtained such.
    /// Must have approved the operator with `controller.addDelegate(daiProxy.address)`.
    /// @param collateral Valid collateral type.
    /// @param maturity Maturity of an added series
    /// @param to Wallet to sent the resulting Dai to.
    /// @param yDaiToBorrow Amount of yDai to borrow.
    /// @param minimumDaiToBorrow Minimum amount of Dai that should be borrowed.
    function borrowMinimumDaiForYDai(
        IPool pool,
        bytes32 collateral,
        uint256 maturity,
        address to,
        uint256 yDaiToBorrow,
        uint256 minimumDaiToBorrow
    )
        public
        returns (uint256)
    {
        // The collateral for this borrow needs to have been posted beforehand
        controller.borrow(collateral, maturity, msg.sender, address(this), yDaiToBorrow);
        uint256 boughtDai = pool.sellYDai(address(this), to, yDaiToBorrow.toUint128());
        require (boughtDai >= minimumDaiToBorrow, "DaiProxy: Not enough Dai obtained");

        return boughtDai;
    }


    /// @dev Repay an amount of yDai debt in Controller using Dai exchanged for yDai at pool rates, up to a maximum amount of Dai spent.
    /// Must have approved the operator with `pool.addDelegate(daiProxy.address)`.
    /// @param collateral Valid collateral type.
    /// @param maturity Maturity of an added series
    /// @param to Yield Vault to repay yDai debt for.
    /// @param yDaiRepayment Amount of yDai debt to repay.
    /// @param maximumRepaymentInDai Maximum amount of Dai that should be spent on the repayment.
    function repayYDaiDebtForMaximumDai(
        IPool pool,
        bytes32 collateral,
        uint256 maturity,
        address to,
        uint256 yDaiRepayment,
        uint256 maximumRepaymentInDai
    )
        public
        returns (uint256)
    {
        uint256 repaymentInDai = pool.buyYDai(msg.sender, address(this), yDaiRepayment.toUint128());
        require (repaymentInDai <= maximumRepaymentInDai, "DaiProxy: Too much Dai required");
        controller.repayYDai(collateral, maturity, address(this), to, yDaiRepayment);

        return repaymentInDai;
    }

    /// @dev Repay an amount of yDai debt in Controller using a given amount of Dai exchanged for yDai at pool rates, with a minimum of yDai debt required to be paid.
    /// Must have approved the operator with `pool.addDelegate(daiProxy.address)`.
    /// @param collateral Valid collateral type.
    /// @param maturity Maturity of an added series
    /// @param to Yield Vault to repay yDai debt for.
    /// @param minimumYDaiRepayment Minimum amount of yDai debt to repay.
    /// @param repaymentInDai Exact amount of Dai that should be spent on the repayment.
    function repayMinimumYDaiDebtForDai(
        IPool pool,
        bytes32 collateral,
        uint256 maturity,
        address to,
        uint256 minimumYDaiRepayment,
        uint256 repaymentInDai
    )
        public
        returns (uint256)
    {
        uint256 yDaiRepayment = pool.sellDai(msg.sender, address(this), repaymentInDai.toUint128());
        require (yDaiRepayment >= minimumYDaiRepayment, "DaiProxy: Not enough yDai debt repaid");
        controller.repayYDai(collateral, maturity, address(this), to, yDaiRepayment);

        return yDaiRepayment;
    }

    /// @dev Sell Dai for yDai
    /// @param to Wallet receiving the yDai being bought
    /// @param daiIn Amount of dai being sold
    /// @param minYDaiOut Minimum amount of yDai being bought
    function sellDai(address pool, address to, uint128 daiIn, uint128 minYDaiOut)
        external
        returns(uint256)
    {
        uint256 yDaiOut = IPool(pool).sellDai(msg.sender, to, daiIn);
        require(
            yDaiOut >= minYDaiOut,
            "LimitPool: Limit not reached"
        );
        return yDaiOut;
    }

    /// @dev Buy Dai for yDai
    /// @param to Wallet receiving the dai being bought
    /// @param daiOut Amount of dai being bought
    /// @param maxYDaiIn Maximum amount of yDai being sold
    function buyDai(address pool, address to, uint128 daiOut, uint128 maxYDaiIn)
        external
        returns(uint256)
    {
        uint256 yDaiIn = IPool(pool).buyDai(msg.sender, to, daiOut);
        require(
            maxYDaiIn >= yDaiIn,
            "LimitPool: Limit exceeded"
        );
        return yDaiIn;
    }

    /// @dev Sell yDai for Dai
    /// @param to Wallet receiving the dai being bought
    /// @param yDaiIn Amount of yDai being sold
    /// @param minDaiOut Minimum amount of dai being bought
    function sellYDai(address pool, address to, uint128 yDaiIn, uint128 minDaiOut)
        external
        returns(uint256)
    {
        uint256 daiOut = IPool(pool).sellYDai(msg.sender, to, yDaiIn);
        require(
            daiOut >= minDaiOut,
            "LimitPool: Limit not reached"
        );
        return daiOut;
    }

    /// @dev Buy yDai for dai
    /// @param to Wallet receiving the yDai being bought
    /// @param yDaiOut Amount of yDai being bought
    /// @param maxDaiIn Maximum amount of dai being sold
    function buyYDai(address pool, address to, uint128 yDaiOut, uint128 maxDaiIn)
        external
        returns(uint256)
    {
        uint256 daiIn = IPool(pool).buyYDai(msg.sender, to, yDaiOut);
        require(
            maxDaiIn >= daiIn,
            "LimitPool: Limit exceeded"
        );
        return daiIn;
    }
}
