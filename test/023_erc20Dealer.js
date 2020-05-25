const ERC20Dealer = artifacts.require('ERC20Dealer');
const ERC20 = artifacts.require('TestERC20');
const TestOracle = artifacts.require('TestOracle');
const Treasury = artifacts.require('Treasury');
const YDai = artifacts.require('YDai');
const Chai = artifacts.require('Chai');
const Pot = artifacts.require('Pot');
const Vat = artifacts.require('Vat');
const GemJoin = artifacts.require('GemJoin');
const DaiJoin = artifacts.require('DaiJoin');
const helper = require('ganache-time-traveler');
const truffleAssert = require('truffle-assertions');
const { BN } = require('@openzeppelin/test-helpers');
const { expectRevert } = require('@openzeppelin/test-helpers');

contract('ERC20Dealer', async (accounts) =>  {
    let [ owner, user ] = accounts;
    let vat;
    let pot;
    let treasury;
    let yDai;
    let chai;
    let weth;
    let wethJoin;
    let dai;
    let daiJoin;
    let oracle;
    let token;
    let dealer;
    let maturity;
    let ilk = web3.utils.fromAscii("ETH-A")
    let Line = web3.utils.fromAscii("Line")
    let spot = web3.utils.fromAscii("spot")
    let linel = web3.utils.fromAscii("line")
    let snapshot;
    let snapshotId;
    const RAY  = "1000000000000000000000000000";
    const RAD = web3.utils.toBN('49')
    const price  = "1100000000000000000000000000";
    const daiTokens = web3.utils.toWei("100");
    const increasedDebt = web3.utils.toWei("150"); // 100 dai * 1.5 rate
    const erc20Tokens = web3.utils.toWei("110");
    const limits =  web3.utils.toBN('10').pow(RAD).toString();
    // console.log(limits);

    const rateIncrease  = "250000000000000000000000000";
    const moreDai = web3.utils.toWei("125"); //  daiTokens * rate
    const remainingDebt = web3.utils.toWei("25"); //  (daiTokens - (daiTokens / rate)) * rate

    beforeEach(async() => {
        snapshot = await helper.takeSnapshot();
        snapshotId = snapshot['result'];

        // Setup vat
        vat = await Vat.new();
        await vat.init(ilk, { from: owner });

        weth = await ERC20.new(0, { from: owner }); 
        wethJoin = await GemJoin.new(vat.address, ilk, weth.address, { from: owner });
        await vat.rely(wethJoin.address, { from: owner });

        dai = await ERC20.new(0, { from: owner });
        daiJoin = await DaiJoin.new(vat.address, dai.address, { from: owner });
        await vat.rely(daiJoin.address, { from: owner });

        await vat.file(ilk, spot,    RAY, { from: owner });
        await vat.file(ilk, linel, limits, { from: owner });
        await vat.file(Line,       limits); // TODO: Why can't we specify `, { from: owner }`?
        await vat.rely(vat.address, { from: owner });

        // Setup pot
        pot = await Pot.new(vat.address);
        await vat.rely(pot.address, { from: owner });
        // Do we need to set the dsr to something different than one?

        // Setup chai
        chai = await Chai.new(
            vat.address,
            pot.address,
            daiJoin.address,
            dai.address,
        );

        // Setup yDai
        const block = await web3.eth.getBlockNumber();
        maturity = (await web3.eth.getBlock(block)).timestamp + 1000;
        yDai = await YDai.new(vat.address, pot.address, maturity, "Name", "Symbol");

        // Set treasury
        treasury = await Treasury.new(
            dai.address,        // dai
            chai.address,       // chai
            weth.address,       // weth
            daiJoin.address,    // daiJoin
            wethJoin.address,   // wethJoin
            vat.address,        // vat
        );
        await vat.rely(treasury.address, { from: owner }); //?

        // Setup Collateral Token
        token = await ERC20.new(0, { from: owner }); 

        // Setup Oracle
        oracle = await TestOracle.new({ from: owner });
        await oracle.setPrice(price); // Setting price at 1.1

        // Setup ERC20Dealer
        dealer = await ERC20Dealer.new(
            treasury.address,
            dai.address,
            yDai.address,
            token.address,
            oracle.address,
            { from: owner },
        );
        treasury.grantAccess(dealer.address, { from: owner });
        yDai.grantAccess(dealer.address, { from: owner });
    });

    afterEach(async() => {
        await helper.revertToSnapshot(snapshotId);
    });

    it("allows user to post collateral", async() => {
        assert.equal(
            (await token.balanceOf(dealer.address)),   
            0,
            "ERC20Dealer has collateral",
        );
        assert.equal(
            (await dealer.powerOf.call(owner)),   
            0,
            "Owner has borrowing power",
        );
        
        await token.mint(owner, erc20Tokens, { from: owner });
        await token.approve(dealer.address, erc20Tokens, { from: owner }); 
        await dealer.post(owner, erc20Tokens, { from: owner });

        assert.equal(
            (await token.balanceOf(dealer.address)),   
            erc20Tokens,
            "ERC20Dealer should have collateral",
        );
        assert.equal(
            (await dealer.powerOf.call(owner)),   
            daiTokens,
            "Owner should have borrowing power",
        );
    });

    describe("with posted collateral", () => {
        beforeEach(async() => {
            await token.mint(owner, erc20Tokens, { from: owner });
            await token.approve(dealer.address, erc20Tokens, { from: owner }); 
            await dealer.post(owner, erc20Tokens, { from: owner });
        });

        it("allows user to withdraw collateral", async() => {
            assert.equal(
                (await token.balanceOf(dealer.address)),   
                erc20Tokens,
                "ERC20Dealer does not have collateral",
            );
            assert.equal(
                (await dealer.powerOf.call(owner)),   
                daiTokens,
                "Owner does not have borrowing power",
            );
            assert.equal(
                (await token.balanceOf(owner)),   
                0,
                "Owner has collateral in hand"
            );
            
            await dealer.withdraw(owner, erc20Tokens, { from: owner });

            assert.equal(
                (await token.balanceOf(owner)),   
                erc20Tokens,
                "Owner should have collateral in hand"
            );
            assert.equal(
                (await token.balanceOf(dealer.address)),   
                0,
                "ERC20Dealer should not have collateral",
            );
            assert.equal(
                (await dealer.powerOf.call(owner)),   
                0,
                "Owner should not have borrowing power",
            );
        });

        it("allows to borrow yDai", async() => {
            assert.equal(
                (await dealer.powerOf.call(owner)),   
                daiTokens,
                "Owner does not have borrowing power",
            );
            assert.equal(
                (await yDai.balanceOf(owner)),   
                0,
                "Owner has yDai",
            );
            assert.equal(
                (await dealer.debtDai.call(owner)),   
                0,
                "Owner has debt",
            );
    
            await dealer.borrow(owner, daiTokens, { from: owner });

            assert.equal(
                (await yDai.balanceOf(owner)),   
                daiTokens,
                "Owner should have yDai",
            );
            assert.equal(
                (await dealer.debtDai.call(owner)),   
                daiTokens,
                "Owner should have debt",
            );
        });

        it("doesn't allow to borrow yDai beyond borrowing power", async() => {
            assert.equal(
                (await dealer.powerOf.call(owner)),   
                daiTokens,
                "Owner does not have borrowing power",
            );
            assert.equal(
                (await dealer.debtDai.call(owner)),   
                0,
                "Owner has debt",
            );
    
            await expectRevert(
                dealer.borrow(owner, moreDai, { from: owner }),
                "ERC20Dealer: Post more collateral",
            );
        });

        describe("with borrowed yDai", () => {
            beforeEach(async() => {
                await dealer.borrow(owner, daiTokens, { from: owner });
            });

            it("doesn't allow to withdraw if undercollateralized", async() => {
                assert.equal(
                    (await dealer.powerOf.call(owner)),   
                    daiTokens,
                    "Owner does not have borrowing power",
                );
                assert.equal(
                    (await dealer.debtDai.call(owner)),   
                    daiTokens,
                    "Owner does not have debt",
                );

                await oracle.setPrice("1200000000000000000000000000"); // Increase price to 1.2
        
                await expectRevert(
                    dealer.withdraw(owner, erc20Tokens, { from: owner }),
                    "ERC20Dealer: Undercollateralized",
                );
            });

            it("doesn't allow to withdraw and become undercollateralized", async() => {
                assert.equal(
                    (await dealer.powerOf.call(owner)),   
                    daiTokens,
                    "Owner does not have borrowing power",
                );
                assert.equal(
                    (await dealer.debtDai.call(owner)),   
                    daiTokens,
                    "Owner does not have debt",
                );

                await expectRevert(
                    dealer.borrow(owner, erc20Tokens, { from: owner }),
                    "ERC20Dealer: Post more collateral",
                );
            });
            
            it("as rate increases after maturity, so does the debt in when measured in dai", async() => {
                assert.equal(
                    (await dealer.debtDai.call(owner)),   
                    daiTokens,
                    "Owner should have " + daiTokens + " debt",
                );
                // yDai matures
                await helper.advanceTime(1000);
                await helper.advanceBlock();
                await yDai.mature();

                // Set rate to 1.5
                await vat.fold(ilk, vat.address, "500000000000000000000000000", { from: owner });
                
                assert.equal(
                    (await dealer.debtDai.call(owner)),   
                    increasedDebt,
                    "Owner should have " + increasedDebt + " debt after the rate change, instead has " + BN(await dealer.debtDai.call(owner)),
                );
            });

            it("as rate increases after maturity, the debt doesn't in when measured in yDai", async() => {
                assert.equal(
                    (await dealer.debtDai.call(owner)),   
                    daiTokens,
                    "Owner should have " + daiTokens + " debt",
                );
                // yDai matures
                await helper.advanceTime(1000);
                await helper.advanceBlock();
                await yDai.mature();

                // Set rate to 1.5
                await vat.fold(ilk, vat.address, "500000000000000000000000000", { from: owner });
                
                let debt = await dealer.debtDai.call(owner);
                assert.equal(
                    (await dealer.inYDai(debt)),   
                    daiTokens,
                    "Owner should have " + daiTokens + " debt after the rate change, instead has " + BN(await dealer.inYDai(debt)),
                );
            });

            it("allows to repay yDai", async() => {
                assert.equal(
                    (await yDai.balanceOf(owner)),   
                    daiTokens,
                    "Owner does not have yDai",
                );
                assert.equal(
                    (await dealer.debtDai.call(owner)),   
                    daiTokens,
                    "Owner does not have debt",
                );

                await yDai.approve(dealer.address, daiTokens, { from: owner });
                await dealer.restore(owner, daiTokens, { from: owner });
    
                assert.equal(
                    (await yDai.balanceOf(owner)),   
                    0,
                    "Owner should not have yDai",
                );
                assert.equal(
                    (await dealer.debtDai.call(owner)),   
                    0,
                    "Owner should not have debt",
                );
            });

            it("allows to repay yDai with dai", async() => {
                // Borrow dai
                await vat.hope(daiJoin.address, { from: owner });
                await vat.hope(wethJoin.address, { from: owner });
                let wethTokens = web3.utils.toWei("500");
                await weth.mint(owner, wethTokens, { from: owner });
                await weth.approve(wethJoin.address, wethTokens, { from: owner });
                await wethJoin.join(owner, wethTokens, { from: owner });
                await vat.frob(ilk, owner, owner, owner, wethTokens, daiTokens, { from: owner });
                await daiJoin.exit(owner, daiTokens, { from: owner });

                assert.equal(
                    (await dai.balanceOf(owner)),   
                    daiTokens,
                    "Owner does not have dai",
                );
                assert.equal(
                    (await dealer.debtDai.call(owner)),   
                    daiTokens,
                    "Owner does not have debt",
                );

                await dai.approve(treasury.address, daiTokens, { from: owner });
                await dealer.repay(owner, daiTokens, { from: owner });
    
                assert.equal(
                    (await dai.balanceOf(owner)),   
                    0,
                    "Owner should not have yDai",
                );
                assert.equal(
                    (await dealer.debtDai.call(owner)),   
                    0,
                    "Owner should not have debt",
                );
            });

            it("when dai is provided in excess fo repayment, only the necessary amount is taken", async() => {
                // Mint some yDai the sneaky way
                await yDai.grantAccess(owner, { from: owner });
                await yDai.mint(owner, remainingDebt, { from: owner }); // 25 extra yDai

                assert.equal(
                    (await yDai.balanceOf(owner)),   
                    moreDai, // Total 125 dai
                    "Owner does not have yDai",
                );
                assert.equal(
                    (await dealer.debtDai.call(owner)),   
                    daiTokens, // 100 dai
                    "Owner does not have debt",
                );

                await yDai.approve(dealer.address, moreDai, { from: owner });
                await dealer.restore(owner, moreDai, { from: owner });
    
                assert.equal(
                    (await yDai.balanceOf(owner)),   
                    remainingDebt,
                    "Owner should have yDai left",
                );
                assert.equal(
                    (await dealer.debtDai.call(owner)),   
                    0,
                    "Owner should not have debt",
                );
            });

            it("more yDai is required to repay after maturity as rate increases", async() => {
                assert.equal(
                    (await yDai.balanceOf(owner)),   
                    daiTokens,
                    "Owner does not have yDai",
                );
                assert.equal(
                    (await dealer.debtDai.call(owner)),   
                    daiTokens,
                    "Owner does not have debt",
                );

                // yDai matures
                await helper.advanceTime(1000);
                await helper.advanceBlock();
                await yDai.mature();

                // Rate increase
                await vat.fold(ilk, vat.address, rateIncrease, { from: owner }); // 1 + 0.25

                assert.equal(
                    (await dealer.debtDai.call(owner)),   
                    moreDai,
                    "Owner does not have increased debt",
                );

                await yDai.approve(dealer.address, daiTokens, { from: owner });
                await dealer.restore(owner, daiTokens, { from: owner });
    
                assert.equal(
                    (await yDai.balanceOf(owner)),   
                    0,
                    "Owner should not have yDai",
                );
                assert.equal(
                    (await dealer.debtDai.call(owner)),   
                    remainingDebt,
                    "Owner should have " + remainingDebt + " dai debt, instead has " + (await dealer.debtDai.call(owner)),
                );
            });

            it("all debt can be repaid after maturity", async() => {
                // Mint some yDai the sneaky way
                await yDai.grantAccess(owner, { from: owner });
                await yDai.mint(owner, remainingDebt, { from: owner });

                assert.equal(
                    (await yDai.balanceOf(owner)),   
                    moreDai,
                    "Owner does not have yDai",
                );
                assert.equal(
                    (await dealer.debtDai.call(owner)),   
                    daiTokens,
                    "Owner does not have debt",
                );

                // yDai matures
                await helper.advanceTime(1000);
                await helper.advanceBlock();
                await yDai.mature();

                // Rate increase
                await vat.fold(ilk, vat.address, rateIncrease, { from: owner }); // 1 + 0.25

                assert.equal(
                    (await dealer.debtDai.call(owner)),   
                    moreDai,
                    "Owner does not have increased debt",
                );

                await yDai.approve(dealer.address, moreDai, { from: owner });
                await dealer.restore(owner, moreDai, { from: owner });
    
                assert.equal(
                    (await yDai.balanceOf(owner)),   
                    0,
                    "Owner should not have yDai",
                );
                assert.equal(
                    (await dealer.debtDai.call(owner)),   
                    0,
                    "Owner should have no remaining debt",
                );
            });
        });
    });
});