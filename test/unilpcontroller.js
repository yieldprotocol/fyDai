const UniLPController = artifacts.require('./UniLPController');
const Treasury = artifacts.require('./Treasury');
const YDai = artifacts.require('./YDai');
const ERC20 = artifacts.require("./TestERC20");
const DaiJoin = artifacts.require('DaiJoin');
const GemJoin = artifacts.require('./GemJoin');
const Pot = artifacts.require('Pot');
const Vat= artifacts.require('./Vat');
const TestOracle = artifacts.require('./TestOracle');
const Uniswap = artifacts.require('./Uniswap');

const truffleAssert = require('truffle-assertions');
const helper = require('ganache-time-traveler');

contract('UniLPController', async (accounts) =>  {
    let [ owner, user ] = accounts;
    let vat;
    let weth;
    let dai;
    let wethJoin;
    let daiJoin;
    let pot;
    let treasury;
    let controller; 
    let collateral;
    let ydai; 
    let oracle;
    let uniswap;
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

        await treasury.grantAccess(user, { from: owner });
        let timestamp = (await web3.eth.getBlock('latest')).timestamp;

        collateral = await ERC20.new(supply, { from: owner });
        ydai = await YDai.new("yDai", "ydai", vat.address, pot.address, timestamp + 1000);
        oracle = await TestOracle.new();
        uniswap = await Uniswap.new();
        controller = await UniLPController.new(
            weth.address,       // weth
            dai.address,        // dai
            collateral.address, // collateral
            treasury.address,   // treasury
            ydai.address,       // ydai
            oracle.address,     // oracle
            vat.address,        // vat
            uniswap.address     // uniswap
        );
    });


    it("should calculate minLocked", async() => {
        const supply0 = web3.utils.toWei("10");
        const supply1 = web3.utils.toWei("40");
        await uniswap.setReserves(supply0, supply1);

        const totalSupply = web3.utils.toWei("20");
        await uniswap.setTotalSupply(totalSupply);

        const amount = web3.utils.toWei("5");
        const n0 = web3.utils.toBN(supply0);
        const n1 = web3.utils.toBN(supply1);
        const tS = web3.utils.toBN(totalSupply);
        let root = Math.sqrt(n0*n1);
        let term = web3.utils.toBN(root);
        let divisor = term.mul(web3.utils.toBN('2'));
        let expectedResult = web3.utils.toBN(amount).mul(tS).div(divisor).toString();

        result = (await controller.minLocked(amount)).toString();
        assert.equal(  
            result, 
            expectedResult
        );

    });


});