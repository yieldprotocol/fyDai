const Flash = artifacts.require("Flash");

module.exports = async (deployer) => {
    await deployer.deploy(
        Flash,
        // treasury
        "0xFa21DE6f225c25b8F13264f1bFF5e1e44a37F96E",
        // DAI-WETH pair:
        // https://etherscan.io/address/0xa478c2975ab1ea89e8196811f51a7b7ade33eb11#readContract
        "0xa478c2975ab1ea89e8196811f51a7b7ade33eb11",
        // liquidations
        "0x357B7E1Bd44f5e48b988a61eE38Bfe9a76983E33"
    );
    const flash = await Flash.deployed()
    console.log({'flash': flash.address})
}
