// External
const Vat = artifacts.require('Vat');
const GemJoin = artifacts.require('GemJoin');
const DaiJoin = artifacts.require('DaiJoin');
const Weth = artifacts.require("WETH9");
const ERC20 = artifacts.require("TestERC20");
const Jug = artifacts.require('Jug');
const Pot = artifacts.require('Pot');
const End = artifacts.require('End');
const Chai = artifacts.require('Chai');
const GasToken = artifacts.require('GasToken1');

// Common
const Treasury = artifacts.require('Treasury');

// YDai
const YDai = artifacts.require('YDai');
const Dealer = artifacts.require('Dealer');

// Market
const Market = artifacts.require('Market');

// Peripheral
const EthProxy = artifacts.require('EthProxy');
const Unwind = artifacts.require('Unwind');
const Splitter = artifacts.require('Splitter');

// Mocks
const FlashMinterMock = artifacts.require('FlashMinterMock');

const truffleAssert = require('truffle-assertions');
const helper = require('ganache-time-traveler');
const { toWad, toRay, toRad, addBN, subBN, mulRay, divRay } = require('../shared/utils');
const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { assert, expect } = require('chai');

contract('Splitter', async (accounts) =>  {
    let [ owner, user ] = accounts;
    let vat;
    let weth;
    let wethJoin;
    let dai;
    let daiJoin;
    let jug;
    let pot;
    let end;
    let chai;
    let gasToken;
    let treasury;
    let yDai1;
    let yDai2;
    let dealer;
    let market1;
    let splitter1;
    let flashMinter;

    let WETH = web3.utils.fromAscii("ETH-A");
    let ilk = web3.utils.fromAscii("ETH-A");
    let Line = web3.utils.fromAscii("Line");
    let spotName = web3.utils.fromAscii("spot");
    let linel = web3.utils.fromAscii("line");

    const limits =  toRad(10000);
    const spot = toRay(1.2);

    const rate1 = toRay(1.4);
    const chi1 = toRay(1.2);
    const rate2 = toRay(1.82);
    const chi2 = toRay(1.5);

    const chiDifferential  = divRay(chi2, chi1);

    const daiDebt1 = toWad(96);
    const daiTokens1 = mulRay(daiDebt1, rate1);
    const yDaiTokens1 = daiTokens1;
    const wethTokens1 = divRay(daiTokens1, spot);
    const chaiTokens1 = divRay(daiTokens1, chi1);

    const daiTokens2 = mulRay(daiTokens1, chiDifferential);
    const wethTokens2 = mulRay(wethTokens1, chiDifferential)

    let maturity;

    // Scenario in which the user mints daiTokens2 yDai1, chi increases by a 25%, and user redeems daiTokens1 yDai1
    const daiDebt2 = mulRay(daiDebt1, chiDifferential);
    const savings1 = daiTokens2;
    const savings2 = mulRay(savings1, chiDifferential);
    const yDaiSurplus = subBN(daiTokens2, daiTokens1);
    const savingsSurplus = subBN(savings2, daiTokens2);

    // Convert eth to weth and use it to borrow `daiTokens` from MakerDAO
    // This function shadows and uses global variables, careful.
    async function getDai(user, daiTokens){
        await vat.hope(daiJoin.address, { from: user });
        await vat.hope(wethJoin.address, { from: user });

        const daiDebt = divRay(daiTokens, rate1);
        const wethTokens = divRay(daiTokens, spot);

        await weth.deposit({ from: user, value: wethTokens });
        await weth.approve(wethJoin.address, wethTokens, { from: user });
        await wethJoin.join(user, wethTokens, { from: user });
        await vat.frob(ilk, user, user, user, wethTokens, daiDebt, { from: user });
        await daiJoin.exit(user, daiTokens, { from: user });
    }

    // From eth, borrow `daiTokens` from MakerDAO and convert them to chai
    // This function shadows and uses global variables, careful.
    async function getChai(user, chaiTokens){
        const daiTokens = mulRay(chaiTokens, chi1);
        await getDai(user, daiTokens);
        await dai.approve(chai.address, daiTokens, { from: user });
        await chai.join(user, daiTokens, { from: user });
    }

    beforeEach(async() => {
        snapshot = await helper.takeSnapshot();
        snapshotId = snapshot['result'];

        // Setup vat, join and weth
        vat = await Vat.new();
        await vat.init(ilk, { from: owner }); // Set ilk rate (stability fee accumulator) to 1.0

        weth = await Weth.new({ from: owner });
        wethJoin = await GemJoin.new(vat.address, ilk, weth.address, { from: owner });

        dai = await ERC20.new(0, { from: owner });
        daiJoin = await DaiJoin.new(vat.address, dai.address, { from: owner });

        await vat.file(ilk, spotName, spot, { from: owner });
        await vat.file(ilk, linel, limits, { from: owner });
        await vat.file(Line, limits);

        // Setup jug
        jug = await Jug.new(vat.address);
        await jug.init(ilk, { from: owner }); // Set ilk duty (stability fee) to 1.0

        // Setup pot
        pot = await Pot.new(vat.address);

        // Permissions
        await vat.rely(vat.address, { from: owner });
        await vat.rely(wethJoin.address, { from: owner });
        await vat.rely(daiJoin.address, { from: owner });
        await vat.rely(jug.address, { from: owner });
        await vat.rely(pot.address, { from: owner });
        await vat.hope(daiJoin.address, { from: owner });

        // Setup chai
        chai = await Chai.new(
            vat.address,
            pot.address,
            daiJoin.address,
            dai.address,
        );

        // Setup Treasury
        treasury = await Treasury.new(
            vat.address,
            weth.address,
            dai.address,
            wethJoin.address,
            daiJoin.address,
            pot.address,
            chai.address,
        );

        // Setup GasToken
        gasToken = await GasToken.new();

        // Setup Dealer
        dealer = await Dealer.new(
            vat.address,
            weth.address,
            dai.address,
            pot.address,
            chai.address,
            gasToken.address,
            treasury.address,
            { from: owner },
        );
        treasury.orchestrate(dealer.address, { from: owner });
        
        // Setup yDai1
        const block = await web3.eth.getBlockNumber();
        maturity = (await web3.eth.getBlock(block)).timestamp + 31556952; // One year
        yDai1 = await YDai.new(
            vat.address,
            jug.address,
            pot.address,
            treasury.address,
            maturity,
            "Name",
            "Symbol"
        );
        await treasury.orchestrate(yDai1.address, { from: owner });
        dealer.addSeries(yDai1.address, { from: owner });
        yDai1.orchestrate(dealer.address, { from: owner });

        // Setup Market
        market1 = await Market.new(
            pot.address,
            chai.address,
            yDai1.address,
            { from: owner }
        );

        // Setup Splitter
        splitter1 = await Splitter.new(
            vat.address,
            weth.address,
            dai.address,
            wethJoin.address,
            daiJoin.address,
            pot.address,
            chai.address,
            treasury.address,
            yDai1.address,
            dealer.address,
            market1.address,
            { from: owner }
        );

        // Test setup
        
        // Increase the rate accumulator
        await vat.fold(ilk, vat.address, subBN(rate1, toRay(1)), { from: owner }); // Fold only the increase from 1.0
        await pot.setChi(chi1, { from: owner }); // Set the savings accumulator

        // Allow owner to mint yDai the sneaky way, without recording a debt in dealer
        await yDai1.orchestrate(owner, { from: owner });

        // Initialize Market1
        await getChai(owner, chaiTokens1)
        await yDai1.mint(owner, yDaiTokens1, { from: owner });

        await chai.approve(market1.address, chaiTokens1, { from: owner });
        await yDai1.approve(market1.address, yDaiTokens1, { from: owner });
        await market1.init(chaiTokens1, yDaiTokens1, { from: owner });
    });

    afterEach(async() => {
        await helper.revertToSnapshot(snapshotId);
    });

    it("moves maker vault to yield", async() => {
        await getDai(user, daiTokens1);

        // Remove these three lines once I find amounts of weth and dai that I can move with both Yield and Maker being safe
        await weth.deposit({ from: user, value: wethTokens1 });
        await weth.approve(treasury.address, wethTokens1, { from: user });
        await dealer.post(WETH, user, user, wethTokens1, { from: user });

        await dealer.addDelegate(splitter1.address, { from: user }); // Allowing Splitter to create debt for use in Yield
        // TODO: Pass on an extra parameter (user) in the data of the flash minting, and flash mint directly on Splitter's wallet. Then remove the next two lines.
        await market1.addDelegate(splitter1.address, { from: user }); // Allowing Splitter to trade for user in Market
        await yDai1.approve(market1.address, yDaiTokens1, { from: user }); // TODO: Ok, this is weird, but the user needs to approve the market to take yDai from him, because the Splitter is going to flash mint in the user's wallet. Refactor so that the Splitter flash mints to itself.
        await vat.hope(splitter1.address, { from: user }); // Allowing Splitter to manipulate debt for user in MakerDAO
        await splitter1.makerToYield(user, yDaiTokens1, wethTokens1.div(2), daiTokens1.div(2), { from: user });
    });

    it("moves maker vault to yield with exact amounts", async() => {
        const debtToMove = daiTokens1.div(10);
        console.log("D: " + debtToMove.toString());
        await getDai(user, debtToMove);

        const wethToMove = await splitter1.wethForDai(debtToMove, { from: user });
        console.log("W: " + wethToMove.toString());

        const yDaiToMint = await splitter1.yDaiForDai(debtToMove, { from: user });
        console.log("Y: " + yDaiToMint.toString());

        await dealer.addDelegate(splitter1.address, { from: user }); // Allowing Splitter to create debt for use in Yield
        // TODO: Pass on an extra parameter (user) in the data of the flash minting, and flash mint directly on Splitter's wallet. Then remove the next two lines.
        await market1.addDelegate(splitter1.address, { from: user }); // Allowing Splitter to trade for user in Market
        await yDai1.approve(market1.address, yDaiToMint, { from: user }); // TODO: Ok, this is weird, but the user needs to approve the market to take yDai from him, because the Splitter is going to flash mint in the user's wallet. Refactor so that the Splitter flash mints to itself.
        await vat.hope(splitter1.address, { from: user }); // Allowing Splitter to manipulate debt for user in MakerDAO
        await splitter1.makerToYield(user, yDaiToMint, wethToMove, debtToMove, { from: user });
    });
});