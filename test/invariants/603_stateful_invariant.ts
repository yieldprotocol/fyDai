const Test = artifacts.require('StatefulInvariantWrapper')
const YieldMath = artifacts.require('YieldMathMock')

// @ts-ignore
import helper from 'ganache-time-traveler'
import { Contract } from '../shared/fixtures'
// @ts-ignore
import { BN } from '@openzeppelin/test-helpers'

contract('YieldMath - Reserves Value Invariant', async (accounts) => {
  let snapshot: any
  let snapshotId: string

  let test: Contract
  let yieldMath: Contract

  const b = new BN('18446744073709551615')
  const k = b.div(new BN('126144000'))
  const g1 = new BN('950').mul(b).div(new BN('1000')) // Sell Dai to the pool
  const g2 = new BN('1000').mul(b).div(new BN('950')) // Sell fyDai to the pool

  beforeEach(async () => {
    snapshot = await helper.takeSnapshot()
    snapshotId = snapshot['result']

    // Setup YieldMathDAIWrapper
    test = await Test.new()
    yieldMath = await YieldMath.new()
  })

  it('Debugs invariant with mint', async () => {
    console.log((await test.whitepaperInvariant()).toString())
    await test.mint('502218703323')
    console.log((await test.whitepaperInvariant()).toString())
  })

  it('Debugs invariant with mint + buyDai', async () => {
    console.log((await test.whitepaperInvariant()).toString())
    await test.mint('64160415248197357243927577754')
    console.log((await test.whitepaperInvariant()).toString())
    await test.buyDai('1379131894488')
    console.log((await test.whitepaperInvariant()).toString())
  })
})
