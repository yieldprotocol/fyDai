const { BN, expectRevert } = require('@openzeppelin/test-helpers');

const YToken = artifacts.require('YToken');
const Vault = artifacts.require('Vault');
const TestOracle = artifacts.require('TestOracle');
const TestERC20 = artifacts.require('TestERC20');
const helper = require('ganache-time-traveler');
const truffleAssert = require('truffle-assertions');

const supply = web3.utils.toWei("1000");
const collateralToPost = web3.utils.toWei("20");
const underlyingToLock = web3.utils.toWei("5");
const underlyingPrice = web3.utils.toWei("2");
const collateralRatio = web3.utils.toWei("2");
const minCollateralRatio = toRay(1.5);

contract('YToken', async (accounts) =>    {
    let yToken;
    let collateral;
    let vault;
    let underlying;
    let maturity;
    const [ owner, user1 ] = accounts;
    const user1collateral = web3.utils.toWei("100");
    const user1underlying = web3.utils.toWei("100");

    beforeEach(async() => {
        let snapshot = await helper.takeSnapshot();
        snapshotId = snapshot['result'];

        underlying = await TestERC20.new(supply, { from: owner });
        await underlying.transfer(user1, user1underlying, { from: owner });
        
        collateral = await TestERC20.new(supply, { from: owner });
        await collateral.transfer(user1, user1collateral, { from: owner });
        const oracle = await TestOracle.new({ from: owner });
        await oracle.set(underlyingPrice, { from: owner });
        vault = await Vault.new(collateral.address, oracle.address, collateralRatio, minCollateralRatio);

        const block = await web3.eth.getBlockNumber();
        maturity = (await web3.eth.getBlock(block)).timestamp + 1000;
        yToken = await YToken.new(underlying.address, vault.address, maturity);
        await vault.transferOwnership(yToken.address);
    });
 
    afterEach(async() => {
        await helper.revertToSnapshot(snapshotId);
    });

    it("yToken should be initialized", async() => {
        assert.equal(
                await yToken.maturity.call(),
                maturity,
        );

        assert.equal(
                await yToken.underlying.call(),
                underlying.address,
        );
    });

    it("yToken can't be borrowed without enough collateral", async() => {
        await truffleAssert.fails(
            yToken.borrow(web3.utils.toWei("10"), { from: user1 }),
            truffleAssert.REVERT,
            "Vault: Not enough collateral",
        );
    });

    it("debts can't be repaid with too many yTokens", async() => {
        helper.advanceTimeAndBlock(1000);
        await truffleAssert.fails(
            yToken.repay(web3.utils.toWei("10"), { from: user1 }),
            truffleAssert.REVERT,
            "YToken: Not enough debt",
        );
    });

    it("yToken are minted with underlying", async() => {
        await underlying.approve(yToken.address, web3.utils.toWei("10"), { from: user1 });
        await yToken.mint(web3.utils.toWei("10"), { from: user1 });
        assert.equal(
                await yToken.balanceOf(user1),
                web3.utils.toWei("10"),
        );
    });

    it("yToken are borrowed with collateral", async() => {
        await collateral.approve(vault.address, collateralToPost, { from: user1 });
        await vault.post(collateralToPost, { from: user1 });

        await underlying.approve(yToken.address, underlyingToLock, { from: user1 });
        await yToken.borrow(underlyingToLock, { from: user1 });
        assert.equal(
                await yToken.balanceOf(user1),
                underlyingToLock,
        );
    });

    it("yToken is not mature before maturity", async() => {
            assert.equal(
                    await yToken.isMature.call(),
                    false,
            );
    });
    
    it("yToken cannot mature before maturity time", async() => {
            await truffleAssert.fails(
                yToken.mature(),
                truffleAssert.REVERT,
                "YToken: Too early to mature",
            );
    });
    
    it("yToken can mature at maturity time", async() => {
            await helper.advanceTime(1000);
            await helper.advanceBlock();
            await yToken.mature();
            assert.equal(
                await yToken.isMature.call(),
                true,
            );
    });

    describe('once users have yTokens', () => {
        beforeEach(async() => {
            await underlying.approve(yToken.address, web3.utils.toWei("10"), { from: user1 });
            await yToken.mint(web3.utils.toWei("10"), { from: user1 });
        });

        it("yToken can't be redeemed before mature()", async() => {
            await helper.advanceTime(1000);
            await helper.advanceBlock();
            await truffleAssert.fails(
                yToken.redeem(web3.utils.toWei("10"), { from: user1 }),
                truffleAssert.REVERT,
                "YToken: Not matured yet",
            );
        });

        it("yToken can be redeemed for underlying", async() => {
            await helper.advanceTime(1000);
            await helper.advanceBlock();
            await yToken.mature();
            await yToken.redeem(web3.utils.toWei("10"), { from: user1 });
            assert.equal(
                    await underlying.balanceOf(user1),
                    user1underlying,
            );
        });

        // TODO: Test redeem for failed underlying transfers
    });

    describe('once users have borrowed yTokens', () => {
        beforeEach(async() => {
            await collateral.approve(vault.address, collateralToPost, { from: user1 });
            await vault.post(collateralToPost, { from: user1 });
    
            await yToken.borrow(underlyingToLock, { from: user1 });
        });

        it("debt can be retrieved", async() => {
            assert.equal(
                await yToken.debtOf(user1),
                underlyingToLock,
            );
        });

        it("yToken debt can be repaid", async() => {
            await yToken.repay(underlyingToLock, { from: user1 });
            assert.equal(
                await yToken.balanceOf(user1),
                0,
            );
            assert.equal(
                await yToken.debtOf(user1),
                0,
            );
        });
    });
});

function toWad(x) {
    const wad = (new BN(10)).pow(new BN(18));
    return (new BN(x).mul(rad)).toString(10);
}

function toRay(x) {
    const ray = (new BN(10)).pow(new BN(27));
    return (new BN(x).mul(ray)).toString(10);
}

function toRad(x) {
    const rad = (new BN(10)).pow(new BN(45));
    return (new BN(x).mul(rad)).toString(10);
}
