const Crytic = artifacts.require('CryticTestYieldMath')

// @ts-ignore
import helper from 'ganache-time-traveler'
import { Contract } from '../shared/fixtures'
// @ts-ignore

contract('YieldMath', async (accounts) => {
  let snapshot: any
  let snapshotId: string

  let test: Contract

  beforeEach(async () => {
    snapshot = await helper.takeSnapshot()
    snapshotId = snapshot['result']

    // Setup YieldMathDAIWrapper
    test = await Crytic.new()
  })

  it('', async () => {
    await test.testLiquidityInvariant();
  })
})
