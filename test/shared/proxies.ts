const ProxyV1 = artifacts.require('ProxyV1')
const YieldProxy = artifacts.require('YieldProxy')

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
