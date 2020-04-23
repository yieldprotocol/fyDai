const { BN, expectRevert } = require('@openzeppelin/test-helpers');

const Vault = artifacts.require('Vault');
const TestERC20 = artifacts.require('TestERC20');
const TestOracle = artifacts.require('TestOracle');
const truffleAssert = require('truffle-assertions');

const supply = web3.utils.toWei("1000");
const user1balance = web3.utils.toWei("100");
const collateralToPost = web3.utils.toWei("20");
const underlyingToLock = web3.utils.toWei("5");
const underlyingPrice = web3.utils.toWei("2");
const collateralRatio = toRay(2);
const tooMuchUnderlying = web3.utils.toWei("6");

contract('Vault', async (accounts) =>    {
    let vault;
    let collateral;
    let oracle;
    const [ owner, user1 ] = accounts;

    beforeEach(async() => {
        collateral = await TestERC20.new(supply, { from: owner });
        await collateral.transfer(user1, user1balance, { from: owner });
        oracle = await TestOracle.new({ from: owner });
        await oracle.set(underlyingPrice, { from: owner });
        vault = await Vault.new(collateral.address, oracle.address, collateralRatio);
    });

    it("collateral can't be retrieved if not available", async() => {
        await truffleAssert.fails(
            vault.retrieve(collateralToPost, { from: user1 }),
            truffleAssert.REVERT,
            "Vault: Unlock more collateral",
        );
    });

    it("collateral can't be locked if not available", async() => {
        await truffleAssert.fails(
            vault.lock(user1, underlyingToLock, { from: owner }),
            truffleAssert.REVERT,
            "Vault: Not enough collateral",
        );
    });

    it("tells how much collateral is needed for a position", async() => {
        assert.equal(
            await vault.collateralNeeded(underlyingToLock, { from: user1 }),
            collateralToPost,
        );
    });

    it("collateral can be posted", async() => {
        await collateral.approve(vault.address, collateralToPost, { from: user1 });
        await vault.post(collateralToPost, { from: user1 });
        assert.equal(
                await vault.balanceOf(user1),
                collateralToPost,
        );
    });

    describe('once collateral is posted', () => {
        beforeEach(async() => {
            await collateral.approve(vault.address, collateralToPost, { from: user1 });
            await vault.post(collateralToPost, { from: user1 });
        });

        it("collateral can be retrieved", async() => {
            await vault.retrieve(collateralToPost, { from: user1 });
            assert.equal(
                    await vault.balanceOf(user1),
                    0,
            );
            assert.equal(
                await collateral.balanceOf(user1),
                user1balance,
            );
        });

        it("collateral can be locked", async() => {
            tx = await vault.lock(user1, underlyingToLock, { from: owner });
            assert.equal(
                tx.logs[0].event,
                "CollateralLocked",
            );
        });

        describe('once collateral is locked', () => {
            beforeEach(async() => {
                await vault.lock(user1, underlyingToLock, { from: owner });
            });

            it("collateral can be unlocked", async() => {
                await vault.lock(user1, 0, { from: owner });
                assert.equal(
                    await vault.unlockedOf(user1),
                    collateralToPost,
                );
            });

            it("it can be known if a position is undercollateralized", async() => {
                assert(await vault.isCollateralized(user1, underlyingToLock));
                await oracle.set(web3.utils.toWei("3"), { from: owner });
                assert((await vault.isCollateralized(user1, underlyingToLock)) == false);
            });
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
