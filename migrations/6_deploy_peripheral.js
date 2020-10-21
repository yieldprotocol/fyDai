const Migrations = artifacts.require('Migrations')
const Controller = artifacts.require('Controller')
const ProxyV1 = artifacts.require('ProxyV1')
const YieldProxy = artifacts.require('YieldProxy')

module.exports = async (deployer) => {
  const migrations = await Migrations.deployed()

  const controller = await Controller.deployed()
  const controllerAddress = controller.address

  const poolAddresses = []
  for (let i = 0; i < (await migrations.length()); i++) {
    const contractName = web3.utils.toAscii(await migrations.names(i))
    if (contractName.includes('fyDaiLP'))
      poolAddresses.push(await migrations.contracts(web3.utils.fromAscii(contractName)))
  }

  // Deploy v1
  await deployer.deploy(ProxyV1)
  const v1 = await ProxyV1.deployed()

  // Deploy the fallback proxy
  await deployer.deploy(YieldProxy)
  const proxy = await YieldProxy.deployed()

  // set the implementation and call the initializer
  const initArgs = v1.contract.methods.init(controllerAddress, poolAddresses).encodeABI()
  await proxy.upgradeTo(v1.address, initArgs)

  // Deploy the Proxy contract
  await deployer.deploy(YieldProxy)
  const yieldProxy = await YieldProxy.deployed()

  const deployment = {
    ProxyV1: v1.address,
    YieldProxy: yieldProxy.address,
  }

  for (name in deployment) {
    await migrations.register(web3.utils.fromAscii(name), deployment[name])
  }
  console.log(deployment)
}
