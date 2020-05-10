const Chai = artifacts.require('./Chai');
const ERC20 = artifacts.require("./TestERC20");
const DaiJoin = artifacts.require('DaiJoin');
const GemJoin = artifacts.require('./GemJoin');
const Vat= artifacts.require('./Vat');
const Pot= artifacts.require('./Pot');

const truffleAssert = require('truffle-assertions');
const helper = require('ganache-time-traveler');

contract('Chai', async (accounts) =>  {
    let [ owner ] = accounts;
    let vat;
    let pot;
    let chai;
    let dai;
    let weth;
    let daiJoin;
    let wethJoin;

    const ilk = web3.utils.fromAscii("ETH-A")
    const Line = web3.utils.fromAscii("Line")
    const spot = web3.utils.fromAscii("spot")
    const linel = web3.utils.fromAscii("line")

    const RAY  = "1000000000000000000000000000";
    const RAD = web3.utils.toBN('45');
    const supply = web3.utils.toWei("1000");
    const limits =  web3.utils.toBN('10000').mul(web3.utils.toBN('10').pow(RAD)).toString(); // 10000 * 10**45

    beforeEach(async() => {
        // Set up vat, join and weth
        vat = await Vat.new();
        await vat.rely(vat.address, { from: owner });

        weth = await ERC20.new(supply, { from: owner }); 
        await vat.init(ilk, { from: owner }); // Set ilk rate to 1.0
        wethJoin = await GemJoin.new(vat.address, ilk, weth.address, { from: owner });
        await vat.rely(wethJoin.address, { from: owner });

        dai = await ERC20.new(supply, { from: owner });
        daiJoin = await DaiJoin.new(vat.address, dai.address, { from: owner });
        await vat.rely(daiJoin.address, { from: owner });

        // Setup vat
        await vat.file(ilk, spot,    RAY, { from: owner });
        await vat.file(ilk, linel, limits, { from: owner });
        await vat.file(Line,       limits); // TODO: Why can't we specify `, { from: owner }`?

        // Setup pot
        pot = await Pot.new(vat.address);
        await vat.rely(pot.address, { from: owner });

        // Setup chai
        chai = await Chai.new(
            vat.address,
            pot.address,
            daiJoin.address,
            dai.address,
        );
        await vat.rely(chai.address, { from: owner });

        // Borrow dai
        await vat.hope(daiJoin.address, { from: owner });
        await vat.hope(wethJoin.address, { from: owner });
        let wethTokens = web3.utils.toWei("500");
        let daiTokens = web3.utils.toWei("100");
        await weth.approve(wethJoin.address, wethTokens, { from: owner });
        await wethJoin.join(owner, wethTokens, { from: owner });
        await vat.frob(ilk, owner, owner, owner, wethTokens, daiTokens, { from: owner });
        await daiJoin.exit(owner, daiTokens, { from: owner });

    });

    it("allows to exchange dai for chai", async() => {
        /* assert.equal(
            (await dai.balanceOf(owner)),   
            web3.utils.toWei("100")
        ); */ // TODO: Test dai balances
        assert.equal(
            (await chai.balanceOf(owner)),   
            web3.utils.toWei("0")
        );
        
        let amount = web3.utils.toWei("100");
        await dai.approve(chai.address, amount, { from: owner }); 
        await chai.join(owner, amount, { from: owner });

        // Test transfer of chai
        /* assert.equal(
            (await dai.balanceOf(owner)),   
            web3.utils.toWei("0")
        ); */
        assert.equal(
            (await chai.balanceOf(owner)),   
            web3.utils.toWei("100")
        );
    });

    describe("with chai", () => {
        beforeEach(async() => {
            let amount = web3.utils.toWei("100");
            await dai.approve(chai.address, amount, { from: owner }); 
            await chai.join(owner, amount, { from: owner });
        });

        it("allows to exchange chai for dai", async() => {
            /* assert.equal(
                (await dai.balanceOf(owner)),   
                web3.utils.toWei("0")
            ); */
            assert.equal(
                (await chai.balanceOf(owner)),   
                web3.utils.toWei("100")
            );
            
            let amount = web3.utils.toWei("100");
            await chai.exit(owner, amount, { from: owner });

            // Test transfer of chai
            /* assert.equal(
                (await dai.balanceOf(owner)),   
                web3.utils.toWei("100")
            ); */
            assert.equal(
                (await chai.balanceOf(owner)),   
                web3.utils.toWei("0")
            );
        });
    });
});