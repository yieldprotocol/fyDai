const UniswapV2Pair = artifacts.require("UniswapV2Pair");
const Flash = artifacts.require("Flash");
const Multicall = artifacts.require('MultiCall');
const Migrations = artifacts.require('Migrations');
const { ethers } = require('ethers')

module.exports = async (deployer) => {
    // const migrations = await Migrations.at("0x0F7e629bd50439f99B47251779406C21a2F347ce")
    const migrations = await Migrations.deployed()
    const weth = await migrations.contracts(ethers.utils.formatBytes32String('Weth'))
    const dai = await migrations.contracts(ethers.utils.formatBytes32String('Dai'))

    // deployer uni v2 for funding arbs
    await deployer.deploy(UniswapV2Pair);
    const pair = await UniswapV2Pair.deployed()
    await pair.initialize(dai, weth);

    const liquidations = await migrations.contracts(ethers.utils.formatBytes32String('Liquidations'))
    const treasury = await migrations.contracts(ethers.utils.formatBytes32String('Treasury'))

    // deploy our flashloaner
    await deployer.deploy(
        Flash,
        treasury,
        pair.address,
        liquidations
    );
    const flash = await Flash.deployed()

    // we use the multicall contract for reducing RPC calls
    await deployer.deploy(Multicall);
    const multicall = await Multicall.deployed()
    await migrations.register(
        ethers.utils.formatBytes32String("Uniswap"),
        pair.address,
    )
    await migrations.register(
        ethers.utils.formatBytes32String("Flash"),
        flash.address,
    )
    await migrations.register(
        ethers.utils.formatBytes32String("Multicall"),
        // "0x2cc8688c5f75e365aaeeb4ea8d6a480405a48d2a",// kovan
        multicall.address,
    )
}
