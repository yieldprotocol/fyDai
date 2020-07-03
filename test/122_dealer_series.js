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

// Peripheral
const EthProxy = artifacts.require('EthProxy');
// const Unwind = artifacts.require('Unwind');

const helper = require('ganache-time-traveler');
const truffleAssert = require('truffle-assertions');
const { BN, expectRevert } = require('@openzeppelin/test-helpers');
const { toWad, toRay, toRad, addBN, subBN, mulRay, divRay } = require('./shared/utils');

contract('Dealer: Multi-Series', async (accounts) =>  {
    let [ owner, user ] = accounts;
    let vat;
    let weth;
    let wethJoin;
    let dai;
    let daiJoin;
    let jug;
    let pot;
    let chai;
    let gasToken;
    let treasury;
    let yDai1;
    let yDai2;
    let dealer;

    let WETH = web3.utils.fromAscii("WETH");
    let CHAI = web3.utils.fromAscii("CHAI");
    let ilk = web3.utils.fromAscii("ETH-A");
    let Line = web3.utils.fromAscii("Line");
    let spotName = web3.utils.fromAscii("spot");
    let linel = web3.utils.fromAscii("line");

    let snapshot;
    let snapshotId;

    const limits = toRad(10000);
    const spot  = toRay(1.5);
    const rate  = toRay(1.25);
    const daiDebt = toWad(120);
    const daiTokens = mulRay(daiDebt, rate);
    const wethTokens = divRay(daiTokens, spot);
    let maturity;

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

        // Setup GasToken
        gasToken = await GasToken.new();

        // Set treasury
        treasury = await Treasury.new(
            vat.address,
            weth.address,
            dai.address,
            wethJoin.address,
            daiJoin.address,
            pot.address,
            chai.address,
        );

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
        
        // Test setup
        await vat.fold(ilk, vat.address, subBN(rate, toRay(1)), { from: owner }); // Fold only the increase from 1.0
    });

    afterEach(async() => {
        await helper.revertToSnapshot(snapshotId);
    });

    it("adds series", async() => {
        // Setup yDai
        const block = await web3.eth.getBlockNumber();
        maturity1 = (await web3.eth.getBlock(block)).timestamp + 1000;
        
        assert.equal(
            await dealer.containsSeries(maturity1),
            false,
            "Dealer should not contain any maturity",
        );

        yDai1 = await YDai.new(
            vat.address,
            jug.address,
            pot.address,
            treasury.address,
            maturity1,
            "Name1",
            "Symbol1",
            { from: owner },
        );
        treasury.orchestrate(yDai1.address, { from: owner });

        await dealer.addSeries(yDai1.address, { from: owner });
        yDai1.orchestrate(dealer.address, { from: owner });

        assert.equal(
            await dealer.containsSeries(maturity1),
            true,
            "Dealer should contain " + (await yDai1.name.call()),
        );
    });

    it("adds several series", async() => {
        // Setup yDai
        const block = await web3.eth.getBlockNumber();
        maturity1 = (await web3.eth.getBlock(block)).timestamp + 1000;
        yDai1 = await YDai.new(
            vat.address,
            jug.address,
            pot.address,
            treasury.address,
            maturity1,
            "Name1",
            "Symbol1",
            { from: owner },
        );
        treasury.orchestrate(yDai1.address, { from: owner });

        maturity2 = (await web3.eth.getBlock(block)).timestamp + 2000;
        yDai2 = await YDai.new(
            vat.address,
            jug.address,
            pot.address,
            treasury.address,
            maturity2,
            "Name2",
            "Symbol2",
            { from: owner },
        );
        treasury.orchestrate(yDai2.address, { from: owner });

        await dealer.addSeries(yDai1.address, { from: owner });
        yDai1.orchestrate(dealer.address, { from: owner });
        await dealer.addSeries(yDai2.address, { from: owner });
        yDai2.orchestrate(dealer.address, { from: owner });

        assert.equal(
            await dealer.containsSeries(maturity1),
            true,
            "Dealer should contain " + (await yDai1.name.call()),
        );
        assert.equal(
            await dealer.containsSeries(maturity2),
            true,
            "Dealer should contain " + (await yDai2.name.call()),
        );
        assert.equal(
            await dealer.series(maturity1),
            yDai1.address,
            "Dealer should have the contract for " + (await yDai1.name.call()),
        );
        assert.equal(
            await dealer.series(maturity2),
            yDai2.address,
            "Dealer should have the contract for " + (await yDai2.name.call()),
        );
    });

    it("can't add same series twice", async() => {
    
        // Setup yDai
        const block = await web3.eth.getBlockNumber();
        maturity1 = (await web3.eth.getBlock(block)).timestamp + 1000;
        yDai1 = await YDai.new(
            vat.address,
            jug.address,
            pot.address,
            treasury.address,
            maturity1,
            "Name1",
            "Symbol1",
            { from: owner },
        );
        treasury.orchestrate(yDai1.address, { from: owner });

        await dealer.addSeries(yDai1.address, { from: owner });
        yDai1.orchestrate(dealer.address, { from: owner });
        await expectRevert(
            dealer.addSeries(yDai1.address, { from: owner }),
            "Dealer: Series already added",
        );
    });
});