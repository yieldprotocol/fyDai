const GasToken = artifacts.require('GasToken1');

const truffleAssert = require('truffle-assertions');

contract('GasTokens', async (accounts) =>  {
    let [ owner ] = accounts;
    let gasToken;

    beforeEach(async() => {
        gasToken = await GasToken.new();
    });

    it("allows to mint gasTokens", async() => {
        await gasToken.mint(10, { from: owner }); 
    });

    it("freeing gasTokens refunds gas", async() => {
        await gasToken.mint(10, { from: owner }); 
        await gasToken.free(10, { from: owner }); 
    });
});