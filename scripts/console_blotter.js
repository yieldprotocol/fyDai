/**
 * This file is a blotter for using yield with the truffle console.
 * Copy and paste sections of code to execute different actions quickly across series
 */

const ethers = require("ethers")

// Instantiate Migrations
migrations = await Migrations.deployed()

// Instantiate other contracts
vat = await Vat.at(await migrations.contracts(ethers.utils.formatBytes32String("Vat")))
weth = await WETH9.at(await migrations.contracts(ethers.utils.formatBytes32String("Weth")))
wethJoin = await GemJoin.at(await migrations.contracts(ethers.utils.formatBytes32String("WethJoin")))
dai = await Dai.at(await migrations.contracts(ethers.utils.formatBytes32String("Dai")))
daiJoin = await DaiJoin.at(await migrations.contracts(ethers.utils.formatBytes32String("DaiJoin")))
pot = await Pot.at(await migrations.contracts(ethers.utils.formatBytes32String("Pot")))
chai = await Chai.at(await migrations.contracts(ethers.utils.formatBytes32String("Chai")))
end = await End.at(await migrations.contracts(ethers.utils.formatBytes32String("End")))
fyDai0 = await FYDai.at(await migrations.contracts(ethers.utils.formatBytes32String("fyDai20Sep26")))
fyDai1 = await FYDai.at(await migrations.contracts(ethers.utils.formatBytes32String("fyDai20Oct3")))
fyDai2 = await FYDai.at(await migrations.contracts(ethers.utils.formatBytes32String("fyDai20Dec31")))
fyDai3 = await FYDai.at(await migrations.contracts(ethers.utils.formatBytes32String("fyDai21Mar31")))
fyDai4 = await FYDai.at(await migrations.contracts(ethers.utils.formatBytes32String("fyDai21Jun30")))
treasury = await Treasury.at(await migrations.contracts(ethers.utils.formatBytes32String("Treasury")))
controller = await Controller.at(await migrations.contracts(ethers.utils.formatBytes32String("Controller")))
liquidations = await Liquidations.at(await migrations.contracts(ethers.utils.formatBytes32String("Liquidations")))
unwind = await Unwind.at(await migrations.contracts(ethers.utils.formatBytes32String("Unwind")))
pool0 = await Pool.at(await migrations.contracts(ethers.utils.formatBytes32String("fyDaiLP20Sep26")))
pool1 = await Pool.at(await migrations.contracts(ethers.utils.formatBytes32String("fyDaiLP20Oct3")))
pool2 = await Pool.at(await migrations.contracts(ethers.utils.formatBytes32String("fyDaiLP20Dec31")))
pool3 = await Pool.at(await migrations.contracts(ethers.utils.formatBytes32String("fyDaiLP21Mar31")))
pool4 = await Pool.at(await migrations.contracts(ethers.utils.formatBytes32String("fyDaiLP21Jun30")))
yieldProxy = await YieldProxy.at(await migrations.contracts(ethers.utils.formatBytes32String("YieldProxy")))
console.log("Contracts sourced")

// Constants
RAY = "000000000000000000000000000"
WAD = "000000000000000000"
FIN = "000000000000000"
THOUSAND = "000"
MILLION = "000000"
BILLION = "000000000"
price = "300" + RAY
MAX = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
Line = ethers.utils.formatBytes32String("Line")
line = ethers.utils.formatBytes32String("line")
spot = ethers.utils.formatBytes32String("spot")
ETH_A = ethers.utils.formatBytes32String("ETH-A")
CHAI = ethers.utils.formatBytes32String("CHAI")

accounts = await web3.eth.getAccounts()
me = accounts[0]

// Maturities
maturity0 = await fyDai0.maturity()
maturity1 = await fyDai1.maturity()
maturity2 = await fyDai2.maturity()
maturity3 = await fyDai3.maturity()
maturity4 = await fyDai4.maturity()

// Approvals
await vat.rely(allan)
await vat.rely(bruce)
await vat.rely(georgios)
await vat.hope(daiJoin.address)
await vat.hope(yieldProxy.address)
await weth.approve(treasury.address, MAX)
await weth.approve(wethJoin.address, MAX)
await dai.approve(chai.address, MAX)
await dai.approve(treasury.address, MAX)
await dai.approve(pool0.address, MAX)
await dai.approve(pool1.address, MAX)
await dai.approve(pool2.address, MAX)
await dai.approve(pool3.address, MAX)
await dai.approve(pool4.address, MAX)
await dai.approve(yieldProxy.address, MAX)
await chai.approve(treasury.address, MAX)
await fyDai0.approve(treasury.address, MAX)
await fyDai1.approve(treasury.address, MAX)
await fyDai2.approve(treasury.address, MAX)
await fyDai3.approve(treasury.address, MAX)
await fyDai4.approve(treasury.address, MAX)
await fyDai0.approve(pool0.address, MAX)
await fyDai1.approve(pool1.address, MAX)
await fyDai2.approve(pool2.address, MAX)
await fyDai3.approve(pool3.address, MAX)
await fyDai4.approve(pool4.address, MAX)

// Add delegates
await controller.addDelegate(yieldProxy.address)
await pool0.addDelegate(yieldProxy.address)
await pool1.addDelegate(yieldProxy.address)
await pool2.addDelegate(yieldProxy.address)
await pool3.addDelegate(yieldProxy.address)
await pool4.addDelegate(yieldProxy.address)

// Obtain Weth    
await weth.deposit({ value: "34" + WAD })

// Obtain Dai
await wethJoin.join(me, "34" + WAD)
await vat.frob(ETH_A, me, me, me, "34" + WAD, "10000" + WAD)
await daiJoin.exit(me, "10000" + WAD)

// Obtain chai
await chai.join(me, "125" + WAD)

// Distribute dai
await dai.transfer(allan, "3" + THOUSAND + WAD)
await dai.transfer(bruce, "3" + THOUSAND + WAD)
await dai.transfer(georgios, "3" + THOUSAND + WAD)

// Init pools (done in migrations)
await pool0.init("1000" + WAD)
await pool1.init("1000" + WAD)
await pool2.init("1000" + WAD)
await pool3.init("1000" + WAD)
await pool4.init("1000" + WAD)

// Borrow
await controller.post(ETH_A, me, me, "10" + WAD)
await controller.post(CHAI, me, me, "125" + WAD)
await controller.borrow(ETH_A, maturity0, me, me, "250" + WAD)
await controller.borrow(ETH_A, maturity1, me, me, "250" + WAD)
await controller.borrow(ETH_A, maturity2, me, me, "250" + WAD)
await controller.borrow(ETH_A, maturity3, me, me, "250" + WAD)
await controller.borrow(ETH_A, maturity4, me, me, "250" + WAD)
await controller.borrow(CHAI, maturity1, me, me, "25" + WAD)
await controller.borrow(CHAI, maturity2, me, me, "25" + WAD)
await controller.borrow(CHAI, maturity3, me, me, "25" + WAD)
await controller.borrow(CHAI, maturity4, me, me, "25" + WAD)

// Add liquidity
await yieldProxy.addLiquidity(pool0.address, "100" + WAD, MAX)
await yieldProxy.addLiquidity(pool1.address, "100" + WAD, MAX)
await yieldProxy.addLiquidity(pool2.address, "100" + WAD, MAX)
await yieldProxy.addLiquidity(pool3.address, "100" + WAD, MAX)
await yieldProxy.addLiquidity(pool4.address, "100" + WAD, MAX)

// Buy and sell
await yieldProxy.sellFYDai(pool0.address, me, tokensToAdd(maturity0, rate, await pool0.getDaiReserves()).toString() + WAD, 0)
await yieldProxy.sellFYDai(pool1.address, me, "20" + WAD, 0)
await yieldProxy.sellFYDai(pool2.address, me, "20" + WAD, 0)
await yieldProxy.sellFYDai(pool3.address, me, "20" + WAD, 0)
await yieldProxy.sellFYDai(pool4.address, me, "20" + WAD, 0)

await yieldProxy.sellDai(pool0.address, me, "10" + WAD, 0)
await yieldProxy.sellDai(pool1.address, me, "10" + WAD, 0)
await yieldProxy.sellDai(pool2.address, me, "10" + WAD, 0)
await yieldProxy.sellDai(pool3.address, me, "10" + WAD, 0)
await yieldProxy.sellDai(pool4.address, me, "10" + WAD, 0)

await yieldProxy.buyFYDai(pool0.address, me, "10" + WAD, MAX)
await yieldProxy.buyFYDai(pool1.address, me, "10" + WAD, MAX)
await yieldProxy.buyFYDai(pool2.address, me, "10" + WAD, MAX)
await yieldProxy.buyFYDai(pool3.address, me, "10" + WAD, MAX)
await yieldProxy.buyFYDai(pool4.address, me, "10" + WAD, MAX)

await yieldProxy.buyDai(pool0.address, me, "10" + WAD, MAX)
await yieldProxy.buyDai(pool1.address, me, "10" + WAD, MAX)
await yieldProxy.buyDai(pool2.address, me, "10" + WAD, MAX)
await yieldProxy.buyDai(pool3.address, me, "10" + WAD, MAX)
await yieldProxy.buyDai(pool4.address, me, "10" + WAD, MAX)

// Repay
(await dai.balanceOf(me)).toString()
(await fyDai0.balanceOf(me)).toString()
(await fyDai1.balanceOf(me)).toString()
(await fyDai2.balanceOf(me)).toString()
(await fyDai3.balanceOf(me)).toString()
(await fyDai4.balanceOf(me)).toString()

(await controller.debtFYDai(ETH_A, maturity0, me)).toString()
(await controller.debtFYDai(ETH_A, maturity1, me)).toString()
(await controller.debtFYDai(ETH_A, maturity2, me)).toString()
(await controller.debtFYDai(ETH_A, maturity3, me)).toString()
(await controller.debtFYDai(ETH_A, maturity4, me)).toString()
(await controller.locked(ETH_A, me)).toString()

(await controller.debtDai(ETH_A, maturity0, me)).toString()
(await controller.debtDai(ETH_A, maturity1, me)).toString()
(await controller.debtDai(ETH_A, maturity2, me)).toString()
(await controller.debtDai(ETH_A, maturity3, me)).toString()
(await controller.debtDai(ETH_A, maturity4, me)).toString()

(await controller.debtFYDai(CHAI, maturity0, me)).toString()
(await controller.debtFYDai(CHAI, maturity1, me)).toString()
(await controller.debtFYDai(CHAI, maturity2, me)).toString()
(await controller.debtFYDai(CHAI, maturity3, me)).toString()
(await controller.debtFYDai(CHAI, maturity4, me)).toString()
(await controller.locked(CHAI, me)).toString()

(await controller.debtDai(CHAI, maturity0, me)).toString()
(await controller.debtDai(CHAI, maturity1, me)).toString()
(await controller.debtDai(CHAI, maturity2, me)).toString()
(await controller.debtDai(CHAI, maturity3, me)).toString()
(await controller.debtDai(CHAI, maturity4, me)).toString()

(await controller.repayDai(ETH_A, maturity0, me, me, "25" + WAD))
(await controller.repayDai(ETH_A, maturity1, me, me, "25" + WAD))
(await controller.repayDai(ETH_A, maturity2, me, me, "25" + WAD))
(await controller.repayDai(ETH_A, maturity3, me, me, "25" + WAD))
(await controller.repayDai(ETH_A, maturity4, me, me, "25" + WAD))

(await controller.repayFYDai(ETH_A, maturity0, me, me, "25" + WAD))
(await controller.repayFYDai(ETH_A, maturity1, me, me, "25" + WAD))
(await controller.repayFYDai(ETH_A, maturity2, me, me, "25" + WAD))
(await controller.repayFYDai(ETH_A, maturity3, me, me, "25" + WAD))
(await controller.repayFYDai(ETH_A, maturity4, me, me, "25" + WAD))

(await controller.repayDai(CHAI, maturity0, me, me, "25" + WAD))
(await controller.repayDai(CHAI, maturity1, me, me, "25" + WAD))
(await controller.repayDai(CHAI, maturity2, me, me, "25" + WAD))
(await controller.repayDai(CHAI, maturity3, me, me, "25" + WAD))
(await controller.repayDai(CHAI, maturity4, me, me, "25" + WAD))

(await controller.repayFYDai(CHAI, maturity0, me, me, "25" + WAD))
(await controller.repayFYDai(CHAI, maturity1, me, me, "25" + WAD))
(await controller.repayFYDai(CHAI, maturity2, me, me, "25" + WAD))
(await controller.repayFYDai(CHAI, maturity3, me, me, "25" + WAD))
(await controller.repayFYDai(CHAI, maturity4, me, me, "25" + WAD))

// Redeem
await fyDai0.redeem(me, me, "1" + WAD)
await fyDai1.redeem(me, me, "1" + WAD)
await fyDai2.redeem(me, me, "1" + WAD)
await fyDai3.redeem(me, me, "1" + WAD)
await fyDai4.redeem(me, me, "1" + WAD)

// Withdraw
(await controller.withdraw(ETH_A, me, me, "500" + FIN))
(await controller.withdraw(CHAI, me, me, "1000" + WAD))

// Remove liquidity
(await pool0.balanceOf(me)).toString()
(await pool1.balanceOf(me)).toString()
(await pool2.balanceOf(me)).toString()
(await pool3.balanceOf(me)).toString()
(await pool4.balanceOf(me)).toString()

await pool0.burn(me, me, "100" + WAD)
await pool1.burn(me, me, "100" + WAD)
await pool2.burn(me, me, "100" + WAD)
await pool3.burn(me, me, "100" + WAD)
await pool4.burn(me, me, "100" + WAD)

// Splitter
await yieldProxy.yieldToMaker(pool3.address, me, '600' + FIN, '25' + WAD, { from: me })
await yieldProxy.makerToYield(pool3.address, me, '500' + FIN, '24' + WAD, { from: me })

// Unwind
await end.cage()
tag = '3333333333333333333333333'
await end.setTag(ETH_A, tag)

await end.setDebt(1)

fix = '3030303030303030303030303'
await end.setFix(ETH_A, fix)

await end.skim(ETH_A, me)

await unwind.unwind()

await unwind.settleTreasury()

await unwind.cashSavings()


(await weth.balanceOf(me)).toString()
(await weth.balanceOf(unwind.address)).toString()

await unwind.settle(ETH_A, me)
await unwind.settle(CHAI, me)
await unwind.redeem(maturity0, me)
await unwind.redeem(maturity1, me)
await unwind.redeem(maturity2, me)
await unwind.redeem(maturity3, me)
await unwind.redeem(maturity4, me)

(await weth.balanceOf(me)).toString()
(await weth.balanceOf(unwind.address)).toString()
