// SPDX-License-Identifier: GPL-3.0-or-later
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
import "../interfaces/IController.sol";
import "../interfaces/IPool.sol";
import "../interfaces/IWeth.sol";
import "../interfaces/IFlashMinter.sol";


/// @dev Splitter migrates vaults between MakerDAO and Yield using flash minting.
contract Splitter is IFlashMinter, DecimalMath {

    bytes32 public constant WETH = "ETH-A";
    bool constant public MTY = true;
    bool constant public YTM = false;

    IVat public vat;
    IWeth public weth;
    IERC20 public dai;
    IGemJoin public wethJoin;
    IDaiJoin public daiJoin;
    IController public controller;

    constructor(
        IController controller_,
        IPool[] memory pools
    ) public {
        controller = IController(controller_);
        ITreasury treasury = controller.treasury();
        daiJoin = treasury.daiJoin();
        wethJoin = treasury.wethJoin();
        vat = treasury.vat();
        weth = treasury.weth();
        dai = treasury.dai();

        vat.hope(address(daiJoin));
        vat.hope(address(wethJoin));

        dai.approve(address(daiJoin), uint(-1));
        weth.approve(address(wethJoin), uint(-1));
        weth.approve(address(treasury), uint(-1));

        for (uint i = 0; i < pools.length; i++) {
            pools[i].yDai().approve(address(pools[i]), uint256(-1));
            dai.approve(address(pools[i]), uint256(-1));
        }
    }

    /// @dev Safe casting from uint256 to int256
    function toInt256(uint256 x) internal pure returns(int256) {
        require(
            x <= uint256(type(int256).max),
            "Treasury: Cast overflow"
        );
        return int256(x);
    }
    
    /// @dev Safe casting from uint256 to uint128
    function toUint128(uint256 x) internal pure returns(uint128) {
        require(
            x <= type(uint128).max,
            "Pool: Cast overflow"
        );
        return uint128(x);
    }

    /// @dev Transfer debt and collateral from MakerDAO to Yield
    /// Needs vat.hope(splitter.address, { from: user });
    /// Needs controller.addDelegate(splitter.address, { from: user });
    /// @param pool The pool to trade in (and therefore yDai series to borrow)
    /// @param user Vault to migrate.
    /// @param wethAmount weth to move from MakerDAO to Yield. Needs to be high enough to collateralize the dai debt in Yield,
    /// and low enough to make sure that debt left in MakerDAO is also collateralized.
    /// @param daiAmount dai debt to move from MakerDAO to Yield. Denominated in Dai (= art * rate)
    function makerToYield(address pool, address user, uint256 wethAmount, uint256 daiAmount) public {
        // The user specifies the yDai he wants to mint to cover his maker debt, the weth to be passed on as collateral, and the dai debt to move
        (uint256 ink, uint256 art) = vat.urns(WETH, user);
        (, uint256 rate,,,) = vat.ilks("ETH-A");
        require(
            daiAmount <= muld(art, rate),
            "Splitter: Not enough debt in Maker"
        );
        require(
            wethAmount <= ink,
            "Splitter: Not enough collateral in Maker"
        );
        // Flash mint the yDai
        IYDai yDai = IPool(pool).yDai();
        yDai.flashMint(
            address(this),
            yDaiForDai(pool, daiAmount),
            abi.encode(MTY, pool, user, wethAmount, daiAmount)
        );
    }

    /// @dev Transfer debt and collateral from MakerDAO to Yield using an encoded signature for controller
    /// Needs vat.hope(splitter.address, { from: user });
    /// @param pool The pool to trade in (and therefore yDai series to borrow)
    /// @param user Vault to migrate.
    /// @param wethAmount weth to move from MakerDAO to Yield. Needs to be high enough to collateralize the dai debt in Yield,
    /// and low enough to make sure that debt left in MakerDAO is also collateralized.
    /// @param daiAmount dai debt to move from MakerDAO to Yield. Denominated in Dai (= art * rate)
    /// @param deadline Latest block timestamp for which the signature is valid
    /// @param v Signature parameter
    /// @param r Signature parameter
    /// @param s Signature parameter
    function makerToYieldBySignature(address pool, address user, uint256 wethAmount, uint256 daiAmount, uint deadline, uint8 v, bytes32 r, bytes32 s) public {
        controller.addDelegateBySignature(msg.sender, address(this), deadline, v, r, s);
        makerToYield(pool, user, wethAmount, daiAmount);
    }

    /// @dev Transfer debt and collateral from Yield to MakerDAO
    /// Needs vat.hope(splitter.address, { from: user });
    /// Needs controller.addDelegate(splitter.address, { from: user });
    /// @param pool The pool to trade in (and therefore yDai series to migrate)
    /// @param user Vault to migrate.
    /// @param yDaiAmount yDai debt to move from Yield to MakerDAO.
    /// @param wethAmount weth to move from Yield to MakerDAO. Needs to be high enough to collateralize the dai debt in MakerDAO,
    /// and low enough to make sure that debt left in Yield is also collateralized.
    function yieldToMaker(address pool, address user, uint256 yDaiAmount, uint256 wethAmount) public {
        IYDai yDai = IPool(pool).yDai();

        // The user specifies the yDai he wants to move, and the weth to be passed on as collateral
        require(
            yDaiAmount <= controller.debtYDai(WETH, yDai.maturity(), user),
            "Splitter: Not enough debt in Yield"
        );
        require(
            wethAmount <= controller.posted(WETH, user),
            "Splitter: Not enough collateral in Yield"
        );
        // Flash mint the yDai
        yDai.flashMint(
            address(this),
            yDaiAmount,
            abi.encode(YTM, pool, user, wethAmount, 0)
        ); // The daiAmount encoded is ignored
    }

    /// @dev Transfer debt and collateral from Yield to MakerDAO using an encoded signature for controller
    /// Needs vat.hope(splitter.address, { from: user });
    /// @param pool The pool to trade in (and therefore yDai series to migrate)
    /// @param user Vault to migrate.
    /// @param yDaiAmount yDai debt to move from Yield to MakerDAO.
    /// @param wethAmount weth to move from Yield to MakerDAO. Needs to be high enough to collateralize the dai debt in MakerDAO,
    /// and low enough to make sure that debt left in Yield is also collateralized.
    /// @param deadline Latest block timestamp for which the signature is valid
    /// @param v Signature parameter
    /// @param r Signature parameter
    /// @param s Signature parameter
    function yieldToMakerBySignature(address pool, address user, uint256 yDaiAmount, uint256 wethAmount, uint deadline, uint8 v, bytes32 r, bytes32 s) public {
        controller.addDelegateBySignature(msg.sender, address(this), deadline, v, r, s);
        yieldToMaker(pool, user, yDaiAmount, wethAmount);
    }

    /// @dev Callback from `YDai.flashMint()`
    function executeOnFlashMint(address, uint256 yDaiAmount, bytes calldata data) external override {
        (bool direction, address pool, address user, uint256 wethAmount, uint256 daiAmount) = 
            abi.decode(data, (bool, address, address, uint256, uint256));
        if(direction == MTY) _makerToYield(pool, user, wethAmount, daiAmount);
        if(direction == YTM) _yieldToMaker(pool, user, yDaiAmount, wethAmount);
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

    /// @dev Amount of yDai debt that will result from migrating Dai debt from MakerDAO to Yield
    function yDaiForDai(address pool, uint256 daiAmount) public view returns (uint256) {
        return IPool(pool).buyDaiPreview(toUint128(daiAmount));
    }

    /// @dev Amount of dai debt that will result from migrating yDai debt from Yield to MakerDAO
    function daiForYDai(address pool, uint256 yDaiAmount) public view returns (uint256) {
        return IPool(pool).buyYDaiPreview(toUint128(yDaiAmount));
    }

    /// @dev Internal function to transfer debt and collateral from MakerDAO to Yield
    /// @param pool The pool to trade in (and therefore yDai series to borrow)
    /// @param user Vault to migrate.
    /// @param wethAmount weth to move from MakerDAO to Yield. Needs to be high enough to collateralize the dai debt in Yield,
    /// and low enough to make sure that debt left in MakerDAO is also collateralized.
    /// @param daiAmount dai debt to move from MakerDAO to Yield. Denominated in Dai (= art * rate)
    /// Needs vat.hope(splitter.address, { from: user });
    /// Needs controller.addDelegate(splitter.address, { from: user });
    function _makerToYield(address pool, address user, uint256 wethAmount, uint256 daiAmount) internal {
        IPool _pool = IPool(pool);
        IYDai yDai = IYDai(_pool.yDai());

        // Pool should take exactly all yDai flash minted. Splitter will hold the dai temporarily
        uint256 yDaiSold = _pool.buyDai(address(this), address(this), toUint128(daiAmount));

        daiJoin.join(user, daiAmount);      // Put the Dai in Maker
        (, uint256 rate,,,) = vat.ilks("ETH-A");
        vat.frob(                           // Pay the debt and unlock collateral in Maker
            "ETH-A",
            user,
            user,
            user,
            -toInt256(wethAmount),               // Removing Weth collateral
            -toInt256(divdrup(daiAmount, rate))  // Removing Dai debt
        );

        vat.flux("ETH-A", user, address(this), wethAmount);             // Remove the collateral from Maker
        wethJoin.exit(address(this), wethAmount);                       // Hold the weth in Splitter
        controller.post(WETH, address(this), user, wethAmount);         // Add the collateral to Yield
        controller.borrow(WETH, yDai.maturity(), user, address(this), yDaiSold); // Borrow the yDai
    }


    /// @dev Internal function to transfer debt and collateral from Yield to MakerDAO
    /// Needs vat.hope(splitter.address, { from: user });
    /// Needs controller.addDelegate(splitter.address, { from: user });
    /// @param pool The pool to trade in (and therefore yDai series to migrate)
    /// @param user Vault to migrate.
    /// @param yDaiAmount yDai debt to move from Yield to MakerDAO.
    /// @param wethAmount weth to move from Yield to MakerDAO. Needs to be high enough to collateralize the dai debt in MakerDAO,
    /// and low enough to make sure that debt left in Yield is also collateralized.
    function _yieldToMaker(address pool, address user, uint256 yDaiAmount, uint256 wethAmount) internal {
        IPool _pool = IPool(pool);
        IYDai yDai = IYDai(_pool.yDai());

        // Pay the Yield debt - Splitter pays YDai to remove the debt of `user`
        // Controller should take exactly all yDai flash minted.
        controller.repayYDai(WETH, yDai.maturity(), address(this), user, yDaiAmount);

        // Withdraw the collateral from Yield, Splitter will hold it
        controller.withdraw(WETH, user, address(this), wethAmount);

        // Post the collateral to Maker, in the `user` vault
        wethJoin.join(user, wethAmount);

        // We are going to need to buy the YDai back with Dai borrowed from Maker
        uint256 daiAmount = _pool.buyYDaiPreview(toUint128(yDaiAmount));

        // Borrow the Dai from Maker
        (, uint256 rate,,,) = vat.ilks("ETH-A"); // Retrieve the MakerDAO stability fee for Weth
        vat.frob(
            "ETH-A",
            user,
            user,
            user,
            toInt256(wethAmount),                   // Adding Weth collateral
            toInt256(divdrup(daiAmount, rate))      // Adding Dai debt
        );
        vat.move(user, address(this), daiAmount.mul(UNIT)); // Transfer the Dai to Splitter within MakerDAO, in RAD
        daiJoin.exit(address(this), daiAmount);             // Splitter will hold the dai temporarily

        // Sell the Dai for YDai at Pool - It should make up for what was taken with repayYdai
        _pool.buyYDai(address(this), address(this), toUint128(yDaiAmount));
    }
}
