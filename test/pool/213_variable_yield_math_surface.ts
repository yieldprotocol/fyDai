const VariableYieldMath = artifacts.require('VariableYieldMathWrapper')

// @ts-ignore
import helper from 'ganache-time-traveler'
import { Contract } from '../shared/fixtures'
// @ts-ignore
import { BN } from '@openzeppelin/test-helpers'
import { expect } from 'chai'
const { bignumber, add, subtract, multiply, divide, pow, floor } = require("mathjs")

function toBigNumber(x: any) {
  if (typeof x == 'object') x = x.toString()
  if (typeof x == 'number') return new BN(x)
  else if (typeof x == 'string') {
    if (x.startsWith('0x') || x.startsWith('0X')) return new BN(x.substring(2), 16)
    else return new BN(x)
  }
}


function buyFYDai(vyDaiReserves: any, fyDaiReserves: any, fyDai: any, timeTillMaturity: any, rate: any) {
    const Z = bignumber(vyDaiReserves)
    const Y = bignumber(fyDaiReserves)
    const T = bignumber(timeTillMaturity)
    const x = bignumber(fyDai)
    const c = bignumber(rate)
    const k = bignumber(1/(4 * 365 * 24 * 60 * 60))    // 1 / seconds in four years
    const g = bignumber(950/1000)
    const t = multiply(k, T)
    const a = subtract(1, multiply(g, t))
    const invA = divide(bignumber(1), a)
    const invC = divide(bignumber(1), c)
    const Za = multiply(c, pow(Z, a))
    const Ya = pow(Y, a)
    const Yxa = pow(subtract(Y, x), a)
    const sum = add(multiply(c, Za), multiply(invC, subtract(Ya, Yxa)))
    const y = subtract(multiply(invC, pow(sum, invA)), Z)

    return y
};

function sellVYDai(vyDaiReserves: any, fyDaiReserves: any, vyDai: any, timeTillMaturity: any, rate: any) {
    const Z = bignumber(vyDaiReserves)
    const Y = bignumber(fyDaiReserves)
    const T = bignumber(timeTillMaturity)
    const x = bignumber(vyDai)
    const c = bignumber(rate)
    const k = bignumber(1/(4 * 365 * 24 * 60 * 60))    // 1 / seconds in four years
    const g = bignumber(950/1000)
    const t = multiply(k, T)
    const a = subtract(1, multiply(g, t))
    const invA = divide(bignumber(1), a)
    const Za = multiply(c, pow(multiply(c, Z), a))
    const Ya = pow(Y, a)
    const Zxa = multiply(c, pow(multiply(c, add(Z, x)), a))
    const sum = subtract(add(Za, Ya), Zxa)
    const y = subtract(Y, pow(sum, invA))

    return y
};

function buyVYDai (vyDaiReserves: any, fyDaiReserves: any, vyDai: any, timeTillMaturity: any, rate: any) {
    const Z = bignumber(vyDaiReserves)
    const Y = bignumber(fyDaiReserves)
    const T = bignumber(timeTillMaturity)
    const x = bignumber(vyDai)
    const c = bignumber(rate)
    const k = bignumber(1/(4 * 365 * 24 * 60 * 60))    // 1 / seconds in four years
    const g = bignumber(1000/950)
    const t = multiply(k, T)
    const a = subtract(1, multiply(g, t))
    const invA = divide(bignumber(1), a)
    const Za = multiply(c, pow(multiply(c, Z), a))
    const Ya = pow(Y, a)
    const Zxa = multiply(c, pow(multiply(c, subtract(Z, x)), a))
    const sum = subtract(add(Za, Ya), Zxa)
    const y = subtract(pow(sum, invA), Y)

    return y
};

function sellFYDai(vyDaiReserves: any, fyDaiReserves: any, fyDai: any, timeTillMaturity: any, rate: any) {
    const Z = bignumber(vyDaiReserves)
    const Y = bignumber(fyDaiReserves)
    const T = bignumber(timeTillMaturity)
    const x = bignumber(fyDai)
    const c = bignumber(rate)
    const k = bignumber(1/(4 * 365 * 24 * 60 * 60))    // 1 / seconds in four years
    const g = bignumber(1000/950)
    const t = multiply(k, T)
    const a = subtract(1, multiply(g, t))
    const invA = divide(bignumber(1), a)
    const invC = divide(bignumber(1), c)
    const Za = multiply(c, pow(Z, a))
    const Ya = pow(Y, a)
    const Yxa = pow(add(Y, x), a)
    const sum = add(Za, subtract(Ya, Yxa))
    const y = subtract(Z, multiply(invC, pow(sum, invA)))

    return y
};

function almostEqual(x: any, y: any, p: any) {
  // Check that abs(x - y) < p:
  const xb = toBigNumber(x)
  const yb = toBigNumber(y)
  const pb = toBigNumber(p)
  const diff = (xb.gt(yb) ? xb.sub(yb) : yb.sub(xb))
  expect(diff).to.be.bignumber.lt(pb)
}

contract('VariableYieldMath - Curve', async (accounts) => {
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
  const OneToken = new BN('1000000000000000000')                // 1e18
  const ONE64 = new BN('18446744073709551616')                  // In 64.64 format
  const secondsInOneYear = new BN(60*60*24*365)                 // Seconds in 4 years
  const secondsInFourYears = secondsInOneYear.mul(FOUR)         // Seconds in 4 years
  const k = ONE64.div(secondsInFourYears)

  const g0 = ONE64                                           // No fees
  const g1 = new BN('950').mul(ONE64).div(new BN('1000'))    // Sell vyDai to the pool
  const g2 = new BN('1000').mul(ONE64).div(new BN('950'))    // Sell fyDai to the pool

  const PRECISION = new BN('10000000000000') // 1e13

  const vyDaiReserves = [
    '100000000000000000000000',
    '1000000000000000000000000',
    '10000000000000000000000000',
    '100000000000000000000000000',
    '1000000000000000000000000000',
  ]
  const fyDaiReserveDeltas = [
    '10000000000000000000',
    '1000000000000000000000',
    '100000000000000000000000',
    '10000000000000000000000000',
    '1000000000000000000000000000',
  ]
  const tradeSizes = [
    '1000000000000000000',
    '10000000000000000000',
    '100000000000000000000',
    '1000000000000000000000',
    '10000000000000000000000',
  ]
  const timesTillMaturity = [
    '4',
    '40',
    '4000',
    '400000',
    '40000000',
  ]
  const exchangeRates = [
    '1.00',
    // '1.01',
    // '1.05',
    // '1.25',
    // '2.00',
  ]

  beforeEach(async () => {
    snapshot = await helper.takeSnapshot()
    snapshotId = snapshot['result']

    // Setup YieldMathWrapper
    yieldMath = await VariableYieldMath.new()
  })

  afterEach(async () => {
    await helper.revertToSnapshot(snapshotId)
  })

  describe('Test scenarios', async () => {
    it('Compare a lattice of on-chain vs off-chain yieldspace trades', async function() {
      this.timeout(0);

      for (var vyDaiReserve of vyDaiReserves) {
        for (var fyDaiReserveDelta of fyDaiReserveDeltas) {
          for (var tradeSize of tradeSizes) {
            for (var timeTillMaturity of timesTillMaturity) {
              for (var exchangeRate of exchangeRates) {
                console.log(`${vyDaiReserve}, ${fyDaiReserveDelta}, ${tradeSize}, ${timeTillMaturity}, ${exchangeRate}`)
                const fyDaiReserve = new BN(vyDaiReserve).add(new BN(fyDaiReserveDelta)).toString()
                const bnRate = new BN((Number(exchangeRate) * 100).toString()).mul(ONE64).div(new BN('100'))
                let offChain = sellFYDai(
                  vyDaiReserve,
                  fyDaiReserve,
                  tradeSize,
                  timeTillMaturity,
                  exchangeRate
                )
                let onChain = await yieldMath.vyDaiOutForFYDaiIn(vyDaiReserve, fyDaiReserve, tradeSize, timeTillMaturity, k, g2, bnRate)
                console.log(`offChain sellFYDai: ${floor(offChain).toFixed()}`)
                console.log(`onChain sellFYDai: ${onChain}`)
                almostEqual(onChain, floor(offChain).toFixed(), PRECISION)

                offChain = buyFYDai(
                  vyDaiReserve,
                  fyDaiReserve,
                  tradeSize,
                  timeTillMaturity,
                  exchangeRate
                )
                onChain = await yieldMath.vyDaiInForFYDaiOut(vyDaiReserve, fyDaiReserve, tradeSize, timeTillMaturity, k, g1, bnRate)
                console.log(`offChain buyFYDai: ${floor(offChain).toFixed()}`)
                console.log(`onChain buyFYDai: ${onChain}`)
                almostEqual(onChain, floor(offChain).toFixed(), PRECISION)

                offChain = sellVYDai(
                  vyDaiReserve,
                  fyDaiReserve,
                  tradeSize,
                  timeTillMaturity,
                  exchangeRate
                )
                onChain = await yieldMath.fyDaiOutForVYDaiIn(vyDaiReserve, fyDaiReserve, tradeSize, timeTillMaturity, k, g1, bnRate)
                console.log(`offChain sellVYDai: ${floor(offChain).toFixed()}`)
                console.log(`onChain sellVYDai: ${onChain}`)
                almostEqual(onChain, floor(offChain).toFixed(), PRECISION)

                offChain = buyVYDai(
                  vyDaiReserve,
                  fyDaiReserve,
                  tradeSize,
                  timeTillMaturity,
                  exchangeRate
                )
                onChain = await yieldMath.fyDaiInForVYDaiOut(vyDaiReserve, fyDaiReserve, tradeSize, timeTillMaturity, k, g2, bnRate)
                console.log(`offChain buyVYDai: ${floor(offChain).toFixed()}`)
                console.log(`onChain buyVYDai: ${onChain}`)
                almostEqual(onChain, floor(offChain).toFixed(), PRECISION)

                console.log()
              }        
            }      
          }    
        }  
      }
    });
  });
})
