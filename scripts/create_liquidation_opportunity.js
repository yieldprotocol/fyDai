const Treasury = artifacts.require('Treasury')
const WETH = artifacts.require('WETH9')
const Controller = artifacts.require('Controller')
const YDai = artifacts.require('EDai')
const Dai = artifacts.require('Dai')
const Vat = artifacts.require('Vat')
const Liquidations = artifacts.require('Liquidations')
const Uniswap = artifacts.require('UniswapV2Pair')
const GemJoin = artifacts.require('GemJoin');
const DaiJoin = artifacts.require('DaiJoin');

const { BigNumber, ethers } = require('ethers')
const { parseEther } = require("ethers/lib/utils")

const bWETH = web3.utils.fromAscii("ETH-A");
const bSpot = web3.utils.fromAscii("spot");

const toRay = (value) => {
  let exponent = BigNumber.from(10).pow(BigNumber.from(17))
  return BigNumber.from((value) * 10 ** 10).mul(exponent)
}

// eth at $225 initially -> spot = 150
const initialSpot = 150
// borrow 150 ydai
const maxAmount = parseEther('150');

// eth at 0.8 * 225 = 180 -> spot = 120
const liquidationSpot = 0.8 * initialSpot

// deposit 1 ether
const amt = 1;

const UNIT = BigNumber.from(10).pow(BigNumber.from(27))
function divRay(x, ray) {
    return UNIT.mul(BigNumber.from(x)).div(BigNumber.from(ray))
}

// Opens a DAI CDP with ETH
async function getDai(user, _daiTokens) {
    const vat = await Vat.deployed()
    const weth = await WETH.deployed()
    const wethJoin= await GemJoin.deployed();
    const daiJoin = await DaiJoin.deployed();

    const ilk = await vat.ilks(bWETH);
    const spot = BigNumber.from(ilk.spot.toString());
    const rate = BigNumber.from(ilk.rate.toString());

    await vat.hope(daiJoin.address, { from: user });
    await vat.hope(wethJoin.address, { from: user });

    const _daiDebt = divRay(_daiTokens, rate);
    const _wethTokens = divRay(_daiTokens, spot).mul(2);

    await weth.deposit({ from: user, value: _wethTokens.toString() });
    await weth.approve(wethJoin.address, _wethTokens, { from: user });
    await wethJoin.join(user, _wethTokens, { from: user });
    await vat.frob(bWETH, user, user, user, _wethTokens, _daiDebt, { from: user });
    await daiJoin.exit(user, _daiTokens, { from: user });
}

module.exports = async (callback) => {
    try { 
    console.log('Creating liquidation opoprtunity')

    const accounts = await web3.eth.getAccounts()
    const user = accounts[2];

    // reset the price on Maker
    const vat = await Vat.deployed();
    await vat.file(bWETH, bSpot, toRay(initialSpot))

    // set the price on Uniswap to be 30% over that
    const reserveRatio = Math.ceil(initialSpot * 3 / 2 * 1.3)
    const uniswap = await Uniswap.deployed()
    let reserves = await uniswap.getReserves()
    let daiRes = BigNumber.from(reserves._reserve0.toString())
    let ethRes = BigNumber.from(reserves._reserve1.toString())

    const weth = await WETH.deployed()
    const wethAmount = parseEther(amt.toString());

    // transfer 10 weth
    await weth.deposit({ from: user, value: wethAmount.mul(10).toString() });
    await weth.transfer(uniswap.address, wethAmount.mul(10), { from: user })

    // mint corresponding DAI
    const dai = await Dai.deployed()
    await getDai(user, ethers.utils.parseEther((10 * reserveRatio).toString()))
    await dai.transfer(uniswap.address, await dai.balanceOf(user), { from: user })
    await uniswap.sync({ from: user })

    const controller = await Controller.deployed();
    const treasury = await Treasury.deployed();

    // get the weth and post it as collateral
    await weth.deposit({ from: user, value: wethAmount.toString() });
    await weth.approve(treasury.address, wethAmount, { from: user })
    await controller.post(bWETH, user, user, wethAmount, { from: user})

    // open the position
    const ydai = await YDai.deployed();
    const maturity = await ydai.maturity();
    await controller.borrow(bWETH, maturity, user, user, maxAmount, { from: user });

    // bump the oracle against us to trigger liquidation
    await vat.file(bWETH, bSpot, toRay(liquidationSpot))

    // wait for the liquidation software to do the magic
    // it should:
    // 1. detect new user by the Posted/Borrowed event (who)
    // 2. Check their liq price (should?)
    // 3. Call `liquidate` (go)
    console.log("Opportunity:", user, bWETH)
    console.log("Is collateralized?", await controller.isCollateralized(bWETH, user))
    console.log("Controller:", controller.address);
    console.log("Liquidations:", Liquidations.address);
        callback()
    } catch (e) {console.log(e)}
}
