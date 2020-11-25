const VariableYieldMath = artifacts.require('VariableYieldMathWrapper')

// @ts-ignore
import helper from 'ganache-time-traveler'
import { Contract } from '../shared/fixtures'
// @ts-ignore
import { BN, expectRevert } from '@openzeppelin/test-helpers'

function toBigNumber(x: any) {
  if (typeof x == 'object') x = x.toString()
  if (typeof x == 'number') return new BN(x)
  else if (typeof x == 'string') {
    if (x.startsWith('0x') || x.startsWith('0X')) return new BN(x.substring(2), 16)
    else return new BN(x)
  }
}

contract('VariableYieldMath - Base', async (accounts) => {
  let snapshot: any
  let snapshotId: string

  let yieldMath: Contract

  const ONE = new BN('1')
  const TWO = new BN('2')
  const THREE = new BN('3')
  const FOUR = new BN('4')
  const TEN = new BN('10')
  const TWENTY = new BN('20')

  const MAX = new BN('340282366920938463463374607431768211455') // type(uint128).max
  const OneToken = new BN('1000000000000000000') // 1e18
  const ONE64 = new BN('18446744073709551616') // In 64.64 format
  const secondsInOneYear = new BN(60 * 60 * 24 * 365) // Seconds in 4 years
  const secondsInFourYears = secondsInOneYear.mul(FOUR) // Seconds in 4 years
  const k = ONE64.div(secondsInFourYears)

  const g0 = ONE64 // No fees
  const g1 = new BN('950').mul(ONE64).div(new BN('1000')) // Sell vyDai to the pool
  const g2 = new BN('1000').mul(ONE64).div(new BN('950')) // Sell fyDai to the pool

  beforeEach(async () => {
    snapshot = await helper.takeSnapshot()
    snapshotId = snapshot['result']

    // Setup VariableYieldMathDAIWrapper
    yieldMath = await VariableYieldMath.new()
  })

  afterEach(async () => {
    await helper.revertToSnapshot(snapshotId)
  })

  describe('fyDaiOutForVYDaiIn reverts', () => {
    beforeEach(async () => {})

    // If time to maturity is higher than 1/k, multiplied or divided by g, we are too far from maturity.
    it('Too far from maturity', async () => {
      await expectRevert(
        yieldMath.fyDaiOutForVYDaiIn(
          OneToken.mul(TEN),
          OneToken.mul(TEN),
          OneToken,
          secondsInFourYears.add(new BN(60 * 60)),
          k,
          g0,
          ONE64
        ),
        'YieldMath: Too far from maturity'
      )
    })

    // If the vyDai reserves, multiplied by c, exceed 2**128, we have too much vyDai to operate
    it('Exchange rate overflow', async () => {
      await expectRevert(
        yieldMath.fyDaiOutForVYDaiIn(
          MAX.div(TWO).add(OneToken),
          OneToken.mul(TEN),
          OneToken,
          secondsInOneYear,
          k,
          g0,
          ONE64.mul(TWO)
        ),
        'YieldMath: Exchange rate overflow'
      )
    })

    // If the vyDai in, added to the vyDai reserves, exceed 2**128, we will have too much vyDai to operate
    it('Too much vyDai in', async () => {
      await expectRevert(
        yieldMath.fyDaiOutForVYDaiIn(MAX, OneToken.mul(TEN), OneToken, secondsInOneYear, k, g0, ONE64),
        'YieldMath: Too much vyDai in'
      )
    })

    // If the fyDai to be obtained exceeds the fyDai reserves, the trade reverts
    it('Insufficient fyDai reserves', async () => {
      await expectRevert(
        yieldMath.fyDaiOutForVYDaiIn(OneToken, OneToken.mul(TEN), OneToken.mul(TWENTY), secondsInOneYear, k, g0, ONE64),
        'YieldMath: Insufficient fyDai reserves'
      )
    })

    /* it("Rounding induced error", async () => {
      await expectRevert(
        yieldMath.fyDaiOutForVYDaiIn(OneToken, OneToken, 0, secondsInOneYear, k, g0, ONE64.mul(TWO)),
        'YieldMath: Rounding induced error'
      )
    }) */
  })

  describe('vyDaiOutForFYDaiIn reverts', () => {
    beforeEach(async () => {})

    // If time to maturity is higher than 1/k, multiplied or divided by g, we are too far from maturity.
    it('Too far from maturity', async () => {
      await expectRevert(
        yieldMath.vyDaiOutForFYDaiIn(
          OneToken.mul(TEN),
          OneToken.mul(TEN),
          OneToken,
          secondsInFourYears.add(new BN(60 * 60)),
          k,
          g0,
          ONE64
        ),
        'YieldMath: Too far from maturity'
      )
    })

    // If the vyDai reserves, multiplied by c, exceed 2**128, we have too much vyDai to operate
    it('Exchange rate overflow', async () => {
      await expectRevert(
        yieldMath.vyDaiOutForFYDaiIn(
          MAX.div(TWO).add(OneToken),
          OneToken.mul(TEN),
          OneToken,
          secondsInOneYear,
          k,
          g0,
          ONE64.mul(TWO)
        ),
        'YieldMath: Exchange rate overflow'
      )
    })

    // If the fyDai in, added to the fyDai reserves, exceed 2**128, we will have too much fyDai to operate
    it('Too much fyDai in', async () => {
      await expectRevert(
        yieldMath.vyDaiOutForFYDaiIn(OneToken.mul(TEN), MAX, OneToken, secondsInOneYear, k, g0, ONE64),
        'YieldMath: Too much fyDai in'
      )
    })

    // If the vyDai to be obtained exceeds the vyDai reserves, the trade reverts
    it('Insufficient vyDai reserves', async () => {
      await expectRevert(
        yieldMath.vyDaiOutForFYDaiIn(OneToken.mul(TEN), OneToken, OneToken.mul(TWENTY), secondsInOneYear, k, g0, ONE64),
        'YieldMath: Insufficient vyDai reserves'
      )
    })

    /* it("Rounding induced error", async () => {
      await expectRevert(
        yieldMath.vyDaiOutForFYDaiIn(OneToken, OneToken, 0, secondsInOneYear, k, g0, ONE64.mul(TWO)),
        'YieldMath: Rounding induced error'
      )
    }) */
  })

  describe('fyDaiInForVYDaiOut reverts', () => {
    beforeEach(async () => {})

    // If time to maturity is higher than 1/k, multiplied or divided by g, we are too far from maturity.
    it('Too far from maturity', async () => {
      await expectRevert(
        yieldMath.fyDaiInForVYDaiOut(
          OneToken.mul(TEN),
          OneToken.mul(TEN),
          OneToken,
          secondsInFourYears.add(new BN(60 * 60)),
          k,
          g0,
          ONE64
        ),
        'YieldMath: Too far from maturity'
      )
    })

    // If the vyDai reserves, multiplied by c, exceed 2**128, we have too much vyDai to operate
    it('Exchange rate overflow', async () => {
      await expectRevert(
        yieldMath.fyDaiInForVYDaiOut(
          MAX.div(TWO).add(OneToken),
          OneToken.mul(TEN),
          OneToken,
          secondsInOneYear,
          k,
          g0,
          ONE64.mul(TWO)
        ),
        'YieldMath: Exchange rate overflow'
      )
    })

    it('Too much vyDai out', async () => {
      await expectRevert(
        yieldMath.fyDaiInForVYDaiOut(OneToken.mul(TWO), OneToken, OneToken.mul(THREE), secondsInOneYear, k, g0, ONE64),
        'YieldMath: Too much vyDai out'
      )
    })

    // If the vyDai to be obtained exceeds the vyDai reserves, the trade reverts
    it('Resulting fyDai reserves too high', async () => {
      await expectRevert(
        yieldMath.fyDaiInForVYDaiOut(OneToken.mul(TEN), MAX, OneToken, secondsInOneYear, k, g0, ONE64),
        'YieldMath: Resulting fyDai reserves too high'
      )
    })

    /* it("Rounding induced error", async () => {
      await expectRevert(
        yieldMath.fyDaiInForVYDaiOut(OneToken, OneToken, 0, secondsInOneYear, k, g0, ONE64.mul(TWO)),
        'YieldMath: Rounding induced error'
      )
    }) */
  })

  describe('vyDaiInForFYDaiOut reverts', () => {
    beforeEach(async () => {})

    // If time to maturity is higher than 1/k, multiplied or divided by g, we are too far from maturity.
    it('Too far from maturity', async () => {
      await expectRevert(
        yieldMath.vyDaiInForFYDaiOut(
          OneToken.mul(TEN),
          OneToken.mul(TEN),
          OneToken,
          secondsInFourYears.add(new BN(60 * 60)),
          k,
          g0,
          ONE64
        ),
        'YieldMath: Too far from maturity'
      )
    })

    // If the vyDai reserves, multiplied by c, exceed 2**128, we have too much vyDai to operate
    it('Exchange rate overflow', async () => {
      await expectRevert(
        yieldMath.vyDaiInForFYDaiOut(
          MAX.div(TWO).add(OneToken),
          OneToken.mul(TEN),
          OneToken,
          secondsInOneYear,
          k,
          g0,
          ONE64.mul(TWO)
        ),
        'YieldMath: Exchange rate overflow'
      )
    })

    it('Too much fyDai out', async () => {
      await expectRevert(
        yieldMath.vyDaiInForFYDaiOut(OneToken, OneToken, OneToken.mul(TWO), secondsInOneYear, k, g0, ONE64),
        'YieldMath: Too much fyDai out'
      )
    })

    // If the vyDai to be traded in makes the vyDai reserves to go over 2**128, the trade reverts
    it('Resulting vyDai reserves too high', async () => {
      await expectRevert(
        yieldMath.vyDaiInForFYDaiOut(MAX.sub(OneToken), OneToken.mul(TEN), OneToken, secondsInOneYear, k, g0, ONE64),
        'YieldMath: Resulting vyDai reserves too high'
      )
    })

    it('Rounding induced error', async () => {
      await expectRevert(
        yieldMath.vyDaiInForFYDaiOut(OneToken, OneToken, 0, secondsInOneYear, k, g0, ONE64.mul(TWO)),
        'YieldMath: Rounding induced error'
      )
    })
  })
})
