const helper = require('ganache-time-traveler');
const { BN, expectRevert } = require('@openzeppelin/test-helpers');
const { WETH, CHAI, spot, rate1: rate, chi1: chi, daiTokens1: daiTokens, chaiTokens1: chaiTokens, wethTokens1: wethTokens, toRay, toRad, addBN, subBN, mulRay, divRay } = require('./../shared/utils');
const { shutdown, setupMaker, newTreasury, newController, newYDai, getDai, getChai, postWeth, postChai, newUnwind, newLiquidations } = require("./../shared/fixtures");

contract('Gas Usage', async (accounts) =>  {
    let [ owner, user1, user2, user3, user4 ] = accounts;
    let vat;
    let weth;
    let wethJoin;
    let dai;
    let daiJoin;
    let jug;
    let pot;
    let end;
    let chai;
    let treasury;
    let yDai1;
    let yDai2;
    let controller;
    let ethProxy;
    let liquidations;
    let unwind;

    let snapshot;
    let snapshotId;

    const yDaiTokens = daiTokens;
    let maturities;
    let series;

    beforeEach(async() => {
        snapshot = await helper.takeSnapshot();
        snapshotId = snapshot['result'];

        ({
            vat,
            weth,
            wethJoin,
            dai,
            daiJoin,
            pot,
            jug,
            chai
        } = await setupMaker());

        treasury = await newTreasury();
        controller = await newController();
        liquidations = await newLiquidations()
        unwind = await newUnwind()

        // Setup yDai
        const block = await web3.eth.getBlockNumber();
        maturity1 = (await web3.eth.getBlock(block)).timestamp + 1000;
        maturity2 = (await web3.eth.getBlock(block)).timestamp + 2000;
        yDai1 = await newYDai(maturity1, "Name", "Symbol");
        yDai2 = await newYDai(maturity2, "Name", "Symbol");
    });

    afterEach(async() => {
        await helper.revertToSnapshot(snapshotId);
    });

    const m = 4; // Number of maturities to test.
    describe("working with " + m + " maturities", () => {
        beforeEach(async() => {
            // Setup yDai
            const block = await web3.eth.getBlockNumber();
            maturities = []; // Clear the registry for each test
            series = []; // Clear the registry for each test
            for (let i = 0; i < m; i++) {
                const maturity = (await web3.eth.getBlock(block)).timestamp + (i*1000); 
                maturities.push(maturity);
                series.push(await newYDai(maturity, "Name", "Symbol"));
            }
        });

        describe("post and borrow", () => {
            beforeEach(async() => {
                // Set the scenario
                
                for (let i = 0; i < maturities.length; i++) {
                    await postWeth(user3, wethTokens);
                    await controller.borrow(WETH, maturities[i], user3, user3, daiTokens, { from: user3 });
                }
            });

            it("borrow a second time (no gas bond)", async() => {
                for (let i = 0; i < maturities.length; i++) {
                    await postWeth(user3, wethTokens);
                    await controller.borrow(WETH, maturities[i], user3, user3, daiTokens, { from: user3 });
                }
            });

            it("repayYDai", async() => {
                for (let i = 0; i < maturities.length; i++) {
                    await series[i].approve(treasury.address, daiTokens, { from: user3 });
                    await controller.repayYDai(WETH, maturities[i], user3, user3, daiTokens, { from: user3 });
                }
            });

            it("repayYDai and retrieve gas bond", async() => {
                for (let i = 0; i < maturities.length; i++) {
                    await series[i].approve(controller.address, daiTokens.mul(2), { from: user3 });
                    await controller.repayYDai(WETH, maturities[i], user3, user3, daiTokens.mul(2), { from: user3 });
                }
            });

            it("repayDai and withdraw", async() => {
                await helper.advanceTime(m * 1000);
                await helper.advanceBlock();
                
                for (let i = 0; i < maturities.length; i++) {
                    await getDai(user3, daiTokens, rate);
                    await dai.approve(treasury.address, daiTokens, { from: user3 });
                    await controller.repayDai(WETH, maturities[i], user3, user3, daiTokens, { from: user3 });
                }
                
                for (let i = 0; i < maturities.length; i++) {
                    await controller.withdraw(WETH, user3, user3, wethTokens, { from: user3 });
                }
            });

            describe("during dss unwind", () => {
                beforeEach(async() => {
                    await shutdown(owner, user1, user2)
                });

                it("single series settle", async() => {
                    await unwind.settle(WETH, user3, { from: user3 });
                });

                it("all series settle", async() => {
                    await unwind.settle(WETH, user3, { from: user3 });
                });
            });
        });
    });
});
