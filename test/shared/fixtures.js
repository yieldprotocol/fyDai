const Vat = artifacts.require('Vat');
const Jug = artifacts.require('Jug');
const GemJoin = artifacts.require('GemJoin');
const DaiJoin = artifacts.require('DaiJoin');
const Weth = artifacts.require("WETH9");
const ERC20 = artifacts.require("TestERC20");
const Pot = artifacts.require('Pot');
const Chai = artifacts.require('Chai');
const Treasury = artifacts.require('Treasury');
const YDai = artifacts.require('YDai');
const Controller = artifacts.require('Controller');

const { WETH, Line, spotName, linel, limits, spot, rate1, chi1, toRay, subBN } = require("./utils");

const setupMaker = async() => {
    // Set up vat, join and weth
    vat = await Vat.new();
    await vat.init(WETH); // Set WETH rate to 1.0

    weth = await Weth.new();
    wethJoin = await GemJoin.new(vat.address, WETH, weth.address);

    dai = await ERC20.new(0);
    daiJoin = await DaiJoin.new(vat.address, dai.address);

    // Setup vat
    await vat.file(WETH, spotName, spot);
    await vat.file(WETH, linel, limits);
    await vat.file(Line, limits); 
    await vat.fold(WETH, vat.address, subBN(rate1, toRay(1))); // Fold only the increase from 1.0

    // Setup pot
    pot = await Pot.new(vat.address);

    // Setup chai
    chai = await Chai.new(
        vat.address,
        pot.address,
        daiJoin.address,
        dai.address,
    );

    await pot.setChi(chi1);

    // Setup jug
    jug = await Jug.new(vat.address);
    await jug.init(WETH); // Set WETH duty (stability fee) to 1.0

    // Permissions
    await vat.rely(vat.address);
    await vat.rely(wethJoin.address);
    await vat.rely(daiJoin.address);
    await vat.rely(pot.address);
    await vat.rely(jug.address);

    treasury = await Treasury.new(
        vat.address,
        weth.address,
        dai.address,
        wethJoin.address,
        daiJoin.address,
        pot.address,
        chai.address,
    );

    return {
        vat,
        weth,
        wethJoin,
        dai,
        daiJoin,
        pot,
        jug,
        chai,
        treasury
    }
}

// Helper for deploying Treasury
async function newTreasury() {
    return Treasury.new(
        vat.address,
        weth.address,
        dai.address,
        wethJoin.address,
        daiJoin.address,
        pot.address,
        chai.address,
    );
}

// Helper for deploying YDai
async function newYDai(maturity, name, symbol) {
    const yDai = await YDai.new(
        vat.address,
        jug.address,
        pot.address,
        treasury.address,
        maturity,
        name,
        symbol,
    );
    controller.addSeries(yDai.address);
    yDai.orchestrate(controller.address);
    treasury.orchestrate(yDai.address);
    return yDai;
}

// Deploys the controller with 2 Ydai contracts with maturities at 1000 and 
// 2000 blocks from now
async function newController() {
    // Setup Controller
    controller = await Controller.new(
        vat.address,
        pot.address,
        treasury.address,
    );
    treasury.orchestrate(controller.address);

    // Setup yDai
    /* const block = await web3.eth.getBlockNumber();
    maturity1 = (await web3.eth.getBlock(block)).timestamp + 1000;
    yDai1 = await newYdai(maturity1, "Name1", "Symbol1")
    controller.addSeries(yDai1.address);
    yDai1.orchestrate(controller.address);
    treasury.orchestrate(yDai1.address);

    maturity2 = (await web3.eth.getBlock(block)).timestamp + 2000;
    yDai2 = await newYdai(maturity2, "Name2", "Symbol2")
    controller.addSeries(yDai2.address);
    yDai2.orchestrate(controller.address);
    treasury.orchestrate(yDai2.address);*/

    return controller;
}

module.exports = {
    setupMaker,
    newTreasury,
    newYDai,
    newController,
}
