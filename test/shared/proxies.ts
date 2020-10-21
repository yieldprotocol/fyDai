const ProxyV1 = artifacts.require('ProxyV1')
const YieldProxy = artifacts.require('YieldProxy')

const ProxyV2 = artifacts.require('ProxyV2')

// Deploys the v1 proxy
export const setupProxy = async (controllerAddress: string, pools: string[]) => {
  const v1 = await ProxyV1.new()
  // deploy the proxy
  let proxy = await YieldProxy.new()

  // set the implementation and call the initializer
  const initArgs = v1.contract.methods.init(controllerAddress, pools).encodeABI()
  await proxy.upgradeTo(v1.address, initArgs)

  // rebind the ABI
  proxy = await ProxyV1.at(proxy.address)
  return proxy
}

// Upgrades to another proxy
export const upgradeToV2 = async (proxy: any) => {
  const v2 = await ProxyV2.new()

  // set the implementation and call the initializer
  const initArgs = v2.contract.methods.init(123).encodeABI()

  // need to override here to access the `upgradeTo` method
  // since we may be given
  proxy = await YieldProxy.at(proxy.address)
  await proxy.upgradeTo(v2.address, initArgs)

  // rebind the ABI
  proxy = await ProxyV2.at(proxy.address)
  return proxy
}
