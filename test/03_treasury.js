const Treasury = artifacts.require('./MockTreasury');
const ERC20 = artifacts.require("./TestERC20");
const DaiJoin = artifacts.require('DaiJoin');
const GemJoin = artifacts.require('./GemJoin');
const Pot = artifacts.require('Pot');
const Vat= artifacts.require('./Vat');

const truffleAssert = require('truffle-assertions');
const helper = require('ganache-time-traveler');

contract('Treasury', async (accounts) =>  {
    let [ owner, user ] = accounts;
    let vat;
    let weth;
    let dai;
    let wethJoin;
    let daiJoin;
    let pot;
    let treasury;
    const ilk = web3.utils.fromAscii("ETH-A")
    const Line = web3.utils.fromAscii("Line")
    const spot = web3.utils.fromAscii("spot")
    const linel = web3.utils.fromAscii("line")

    const ray  = "1000000000000000000000000000";
    const supply = web3.utils.toWei("1000");
    const rad = web3.utils.toBN('45')
    const limits =  web3.utils.toBN('10000').mul(web3.utils.toBN('10').pow(rad)).toString(); // 10000 * 10**45
    const mockAddress = accounts[9];
    // console.log(limits);

    beforeEach(async() => {
        // Set up vat, join and weth
        vat = await Vat.new();
        await vat.rely(vat.address, { from: owner });

        weth = await ERC20.new(supply, { from: owner }); 
        await vat.init(ilk, { from: owner }); // Set ilk rate to 1.0
        wethJoin = await GemJoin.new(vat.address, ilk, weth.address, { from: owner });
        await vat.rely(wethJoin.address, { from: owner });

        dai = await ERC20.new(0, { from: owner });
        daiJoin = await DaiJoin.new(vat.address, dai.address, { from: owner });
        await vat.rely(daiJoin.address, { from: owner });

        // Setup vat
        await vat.file(ilk, spot,    ray, { from: owner });
        await vat.file(ilk, linel, limits, { from: owner });
        await vat.file(Line,       limits); // TODO: Why can't we specify `, { from: owner }`?

        // Setup pot
        pot = await Pot.new(vat.address);
        await vat.rely(pot.address, { from: owner });

        treasury = await Treasury.new(
            weth.address,       // weth
            dai.address,        // dai
            wethJoin.address,   // wethJoin
            daiJoin.address,    // daiJoin
            vat.address,        // vat
            pot.address         // pot
        );
        //await vat.rely(treasury.address, { from: owner }); //?

        await treasury.grantAccess(user, { from: owner });
    });
    
    it("should fail for failed weth transfers", async() => {
        // Let's check how WETH is implemented, maybe we can remove this one.
    });

    it("allows user to post collateral", async() => {
        assert.equal(
            (await weth.balanceOf(wethJoin.address)),   
            web3.utils.toWei("0")
        );
        
        let amount = web3.utils.toWei("500");
        await weth.mint(user, amount, { from: user });
        await weth.approve(treasury.address, amount, { from: user }); 
        await treasury.post(user, amount, { from: user });

        // Test transfer of collateral
        assert.equal(
            (await weth.balanceOf(wethJoin.address)),   
            web3.utils.toWei("500")
        );

        // Test collateral registering via `frob`
        let ink = (await vat.urns(ilk, treasury.address)).ink.toString()
        assert.equal(
            ink,   
            amount
        );
    });

    describe("with posted collateral", () => {
        beforeEach(async() => {
            let amount = web3.utils.toWei("500");
            await weth.mint(user, amount, { from: user });
            await weth.approve(treasury.address, amount, { from: user }); 
            await treasury.post(user, amount, { from: user });
        });

        it("allows user to withdraw collateral", async() => {
            assert.equal(
                (await weth.balanceOf(user)),   
                web3.utils.toWei("0")
            );
            
            let amount = web3.utils.toWei("500");
            await treasury.withdraw(user, amount, { from: user });

            // Test transfer of collateral
            assert.equal(
                (await weth.balanceOf(user)),   
                web3.utils.toWei("500")
            );

            // Test collateral registering via `frob`
            let ink = (await vat.urns(ilk, treasury.address)).ink.toString()
            assert.equal(
                ink,   
                0
            );
        });

        it("internally allows to borrow dai", async() => {
            // Test with two different stability rates, if possible.
            // Mock Vat contract needs a `setRate` and an `ilks` functions.
            // Mock Vat contract needs the `frob` function to authorize `daiJoin.exit` transfers through the `dart` parameter.
            let daiBorrowed = web3.utils.toWei("100");
            await treasury.borrowDai(user, daiBorrowed, { from: owner });

            let daiBalance = (await dai.balanceOf(user)).toString();
            assert.equal(
                daiBalance,   
                daiBorrowed
            );
            // assert treasury debt = daiBorrowed
        });

        it("internally allows to save dai in the Pot", async() => {
            // Test with two different stability rates, if possible.
            // Mock Vat contract needs a `setRate` and an `ilks` functions.
            // Mock Vat contract needs the `frob` function to authorize `daiJoin.exit` transfers through the `dart` parameter.
            let daiBorrowed = web3.utils.toWei("100");
            await treasury.borrowDai(user, daiBorrowed, { from: owner });

            let daiBalance = (await dai.balanceOf(user)).toString();
            assert.equal(
                daiBalance,   
                daiBorrowed
            );
            // assert treasury debt = daiBorrowed
            /* assert.equal(
                (await vat.dai(treasury.address)).toString(),   
                daiBorrowed
            ); */ // Not sure if I'm not checking treasury dai debt right
        });

        it("borrows dai if there is none in the Pot", async() => {
            let daiBorrowed = web3.utils.toWei("100");
            await treasury.disburse(user, daiBorrowed, { from: user });

            let daiBalance = (await dai.balanceOf(user)).toString();
            assert.equal(
                daiBalance,   
                daiBorrowed
            );
            // assert treasury debt = daiBorrowed
            /* assert.equal(
                (await vat.dai(treasury.address)).toString(),   
                daiBorrowed
            ); */ // Not sure if I'm not checking treasury dai debt right
        });
    
        describe("with a dai debt towards MakerDAO", () => {
            beforeEach(async() => {
                let daiBorrowed = web3.utils.toWei("100");
                await treasury.disburse(user, daiBorrowed, { from: user });
            });

            it("internally repays Dai debt and no more", async() => {
                // Test `normalizedAmount >= normalizedDebt`
                let daiBorrowed = web3.utils.toWei("100");
                await dai.transfer(treasury.address, daiBorrowed, { from: user });
                await treasury.repayDai({ from: owner });
                let daiBalance = (await dai.balanceOf(user)).toString();
                assert.equal(
                    daiBalance,   
                    0
                );
                // assert treasury debt = 0
                assert.equal(
                    (await vat.dai(treasury.address)).toString(),   
                    0
                );

                // Test `normalizedAmount < normalizedDebt`
                // Mock Vat contract needs to return `normalizedDebt` with a `urns` function
                // The DaiJoin mock contract needs to have a `join` function that authorizes Vat for incoming dai transfers.
                // The DaiJoin mock contract needs to have a function to return it's dai balance.
                // The Vat mock contract needs to have a frob function that takes `dart` dai from user to DaiJoin
                // Should transfer funds from daiJoin
            });

            it("repays dai if there is a debt, but no more", async() => {
                // Test `normalizedAmount >= normalizedDebt`
                let daiBorrowed = web3.utils.toWei("100");
                await dai.approve(treasury.address, daiBorrowed, { from: user });
                await treasury.repay(user, daiBorrowed, { from: user });
                let daiBalance = (await dai.balanceOf(user)).toString();
                assert.equal(
                    daiBalance,   
                    0
                );
                // assert treasury debt = 0
                assert.equal(
                    (await vat.dai(treasury.address)).toString(),   
                    0
                );
            });
        });

        describe("without a dai debt towards MakerDAO", () => {
            beforeEach(async() => {
                // Generate dai without generating debt for treasury
                let wethPosted = web3.utils.toWei("60");
                let daiBorrowed = web3.utils.toWei("10");
                await weth.approve(wethJoin.address, wethPosted, { from: owner });
                await wethJoin.join(owner, wethPosted, { from: owner });
                // owner gets the debt for generating the dai
                await vat.rely(owner, { from: owner }); // Some hacking going on here
                await vat.frob(ilk, owner, owner, owner, wethPosted, daiBorrowed, { from: owner });
                await vat.hope(daiJoin.address, { from: owner }); // Owner allows daiJoin to deal with its dai in the vat
                await daiJoin.exit(owner, daiBorrowed, { from: owner });
            });

            it("internally transfers all dai into the Pot", async() => {
                // Test with dai.balanceOf(address(this)) > 0 && pot.chi() != 1
                // The mock Pot contract should inherit from ERC20 and `join` should be a pre-approved `transferFrom`
                let daiBorrowed = web3.utils.toWei("10");
                await dai.transfer(treasury.address, daiBorrowed, { from: owner });
                await treasury.lockDai({ from: owner });
                assert.equal(
                    (await pot.pie(treasury.address)).toString(),   
                    daiBorrowed
                );
            });

            it("locks dai in the Pot if there is no debt", async() => {
                let daiBorrowed = web3.utils.toWei("10");
                await dai.transfer(user, daiBorrowed, { from: owner });
                await dai.approve(treasury.address, daiBorrowed, { from: user });
                await treasury.repay(user, daiBorrowed, { from: user });
                let daiBalance = (await dai.balanceOf(user)).toString();
                assert.equal(
                    daiBalance,   
                    0
                );
                assert.equal(
                    (await pot.pie(treasury.address)).toString(),   
                    daiBorrowed
                );
                // Test with `normalizedDebt == 0 && amount > 0`
                // Test with `normalizedDebt > 0 && amount > normalizedDebt`
            });
    
            describe("with dai in the Pot", () => {
                beforeEach(async() => {
                    let daiBorrowed = web3.utils.toWei("10");
                    await dai.transfer(treasury.address, daiBorrowed, { from: owner });
                    await treasury.lockDai({ from: owner });
                });
        
                it("internally retrieves dai from the Pot", async() => {
                    let daiBorrowed = web3.utils.toWei("10");
                    await treasury.freeDai(daiBorrowed, { from: owner });
                    assert.equal(
                        (await pot.pie(treasury.address)).toString(),   
                        0
                    );
                    const daiBorrowedInRad =  web3.utils.toBN('10').mul(web3.utils.toBN('10').pow(rad)).toString(); // 10 * 10**45
                    assert.equal(
                        (await vat.dai(treasury.address)).toString(),   
                        daiBorrowedInRad
                    );
                });

                it("disburses dai from the Pot if there is any", async() => {
                    let daiBorrowed = web3.utils.toWei("10");
                    assert.equal(
                        (await pot.pie(treasury.address)).toString(),   
                        daiBorrowed
                    );
                    await treasury.disburse(user, daiBorrowed, { from: user });

                    let daiBalance = (await dai.balanceOf(user)).toString();
                    assert.equal(
                        daiBalance,   
                        daiBorrowed
                    );
                    assert.equal(
                        (await pot.pie(treasury.address)).toString(),   
                        0
                    ); // It seems to call _borrowDai instead of _freeDai
                });
            });
        });
    });
});