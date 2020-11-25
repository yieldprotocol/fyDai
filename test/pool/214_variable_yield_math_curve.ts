const VariableYieldMath = artifacts.require('VariableYieldMathWrapper')

// @ts-ignore
import helper from 'ganache-time-traveler'
import { Contract } from '../shared/fixtures'
// @ts-ignore
import { BN } from '@openzeppelin/test-helpers'
import { expect } from 'chai'

/**
 * Throws given message unless given condition is true.
 *
 * @param message message to throw unless given condition is true
 * @param condition condition to check
 */
function assert(message: string, condition: boolean) {
  if (!condition) throw message
}

function toBigNumber(x: any) {
  if (typeof x == 'object') x = x.toString()
  if (typeof x == 'number') return new BN(x)
  else if (typeof x == 'string') {
    if (x.startsWith('0x') || x.startsWith('0X')) return new BN(x.substring(2), 16)
    else return new BN(x)
  }
}

contract('VariableYieldMath - Curve', async (accounts) => {
  let snapshot: any
  let snapshotId: string

  let yieldMath: Contract

  const b = new BN('18446744073709551615')
  const k = b.div(new BN('126144000'))
  const g1 = new BN('950').mul(b).div(new BN('1000')) // Sell Dai to the pool
  const g2 = new BN('1000').mul(b).div(new BN('950')) // Sell fyDai to the pool

  const ONE64 = new BN('18446744073709551616') // In 64.64 format

  const values = [
    ['10000000000000000000000', '1000000000000000000000', '10000000000000000000', '1000000'],
    ['100000000000000000000000000', '10000000000000000000000000', '1000000000000000000000', '1000000'],
    ['1000000000000000000000000000000', '100000000000000000000000000000', '100000000000000000000000', '1000000'],
  ]
  const timeTillMaturity = ['0', '40', '4000', '400000', '40000000']

  beforeEach(async () => {
    snapshot = await helper.takeSnapshot()
    snapshotId = snapshot['result']

    // Setup YieldMathDAIWrapper
    yieldMath = await VariableYieldMath.new()
  })

  afterEach(async () => {
    await helper.revertToSnapshot(snapshotId)
  })

  describe('Test trading functions', async () => {
    it('A higher g means more fyDai out with `fyDaiOutForVYDaiIn`', async () => {
      for (var i = 0; i < values.length; i++) {
        var daiReservesValue = values[i][0]
        var fyDaiReservesValue = values[i][1]
        var daiAmountValue = values[i][2]
        var timeTillMaturityValue = values[i][3]

        var daiReserves = toBigNumber(daiReservesValue)
        var fyDaiReserves = toBigNumber(fyDaiReservesValue)
        var daiAmount = toBigNumber(daiAmountValue)
        var timeTillMaturity = toBigNumber(timeTillMaturityValue)
        var g = [
          ['9', '10'],
          ['95', '100'],
          ['950', '1000'],
        ]
        var previousResult = new BN('0')
        for (var j = 0; j < g.length; j++) {
          var g_ = new BN(g[j][0]).mul(b).div(new BN(g[j][1]))
          var result = await yieldMath.fyDaiOutForVYDaiIn(
            daiReserves,
            fyDaiReserves,
            daiAmount,
            timeTillMaturity,
            k,
            g_,
            ONE64
          )
        }

        expect(result).to.be.bignumber.gt(previousResult.toString())
        previousResult = result
      }
    })

    it('As we approach maturity, price grows to 1 for `fyDaiOutForVYDaiIn`', async () => {
      for (var i = 0; i < values.length; i++) {
        // console.log("")
        var daiReservesValue = values[i][0]
        var fyDaiReservesValue = values[i][1]
        var daiAmountValue = values[i][2]

        var daiReserves = toBigNumber(daiReservesValue)
        var fyDaiReserves = toBigNumber(fyDaiReservesValue)
        var daiAmount = toBigNumber(daiAmountValue)

        const flatFee = new BN('1000000000000')
        const maximum = daiAmount.sub(flatFee)
        var previousResult = maximum
        for (var j = 0; j < timeTillMaturity.length; j++) {
          var t = timeTillMaturity[j]

          var result = await yieldMath.fyDaiOutForVYDaiIn(daiReserves, fyDaiReserves, daiAmount, t, k, g1, ONE64)

          // console.log("      " + result.toString())
          if (j == 0) {
            // Test that when we are very close to maturity, price is very close to 1 minus flat fee.
            expect(result).to.be.bignumber.lt(maximum.mul(new BN('1000000')).div(new BN('999999')).toString())
            expect(result).to.be.bignumber.gt(maximum.mul(new BN('999999')).div(new BN('1000000')).toString())
          } else {
            // Easier to test prices diverging from 1
            expect(result).to.be.bignumber.lt(previousResult.toString())
          }
          previousResult = result
        }
      }
    })

    it('A lower g means more Dai out with `vyDaiOutForFYDaiIn`', async () => {
      for (var i = 0; i < values.length; i++) {
        var daiReservesValue = values[i][0]
        var fyDaiReservesValue = values[i][1]
        var daiAmountValue = values[i][2]
        var timeTillMaturityValue = values[i][3]

        var daiReserves = toBigNumber(daiReservesValue)
        var fyDaiReserves = toBigNumber(fyDaiReservesValue)
        var daiAmount = toBigNumber(daiAmountValue)
        var timeTillMaturity = toBigNumber(timeTillMaturityValue)

        var g = [
          ['950', '1000'],
          ['95', '100'],
          ['9', '10'],
        ]
        var previousResult = new BN('0')
        for (var j = 0; j < g.length; j++) {
          var g_ = new BN(g[j][0]).mul(b).div(new BN(g[j][1]))
          var result = await yieldMath.vyDaiOutForFYDaiIn(
            daiReserves,
            fyDaiReserves,
            daiAmount,
            timeTillMaturity,
            k,
            g_,
            ONE64
          )
        }

        expect(result).to.be.bignumber.gt(previousResult.toString())
        previousResult = result
      }
    })

    it('As we approach maturity, price drops to 1 for `vyDaiOutForFYDaiIn`', async () => {
      for (var i = 0; i < values.length; i++) {
        // console.log("")
        var daiReservesValue = values[i][0]
        var fyDaiReservesValue = values[i][1]
        var daiAmountValue = values[i][2]

        var daiReserves = toBigNumber(daiReservesValue)
        var fyDaiReserves = toBigNumber(fyDaiReservesValue)
        var daiAmount = toBigNumber(daiAmountValue)

        const flatFee = new BN('1000000000000')
        const minimum = daiAmount.sub(flatFee)
        var previousResult = minimum
        for (var j = 0; j < timeTillMaturity.length; j++) {
          var t = timeTillMaturity[j]
          var result = await yieldMath.vyDaiOutForFYDaiIn(daiReserves, fyDaiReserves, daiAmount, t, k, g2, ONE64)

          // console.log("      " + result.toString())
          if (j == 0) {
            // Test that when we are very close to maturity, price is very close to 1 minus flat fee.
            expect(result).to.be.bignumber.gt(minimum.mul(new BN('999999')).div(new BN('1000000')).toString())
            expect(result).to.be.bignumber.lt(minimum.mul(new BN('1000000')).div(new BN('999999')).toString())
          } else {
            // Easier to test prices diverging from 1
            expect(result).to.be.bignumber.gt(previousResult.toString())
          }
          previousResult = result
        }
      }
    })

    it('A higher g means more fyDai in with `fyDaiInForVYDaiOut`', async () => {
      for (var i = 0; i < values.length; i++) {
        var daiReservesValue = values[i][0]
        var fyDaiReservesValue = values[i][1]
        var daiAmountValue = values[i][2]
        var timeTillMaturityValue = values[i][3]

        var daiReserves = toBigNumber(daiReservesValue)
        var fyDaiReserves = toBigNumber(fyDaiReservesValue)
        var daiAmount = toBigNumber(daiAmountValue)
        var timeTillMaturity = toBigNumber(timeTillMaturityValue)

        var g = [
          ['9', '10'],
          ['95', '100'],
          ['950', '1000'],
        ]
        var previousResult = new BN('0')
        for (var j = 0; j < g.length; j++) {
          var g_ = new BN(g[j][0]).mul(b).div(new BN(g[j][1]))
          var result = await yieldMath.fyDaiInForVYDaiOut(
            daiReserves,
            fyDaiReserves,
            daiAmount,
            timeTillMaturity,
            k,
            g_,
            ONE64
          )
        }

        expect(result).to.be.bignumber.gt(previousResult.toString())
        previousResult = result
      }
    })

    it('As we approach maturity, price grows to 1 for `fyDaiInForVYDaiOut`', async () => {
      for (var i = 0; i < values.length; i++) {
        // console.log("")
        var daiReservesValue = values[i][0]
        var fyDaiReservesValue = values[i][1]
        var daiAmountValue = values[i][2]

        var daiReserves = toBigNumber(daiReservesValue)
        var fyDaiReserves = toBigNumber(fyDaiReservesValue)
        var daiAmount = toBigNumber(daiAmountValue)

        const flatFee = new BN('1000000000000')
        const maximum = daiAmount.add(flatFee)
        var previousResult = maximum
        for (var j = 0; j < timeTillMaturity.length; j++) {
          var t = timeTillMaturity[j]
          var result = await yieldMath.fyDaiInForVYDaiOut(daiReserves, fyDaiReserves, daiAmount, t, k, g2, ONE64)

          // console.log("      " + result.toString())
          if (j == 0) {
            // Test that when we are very close to maturity, price is very close to 1 plus flat fee.
            expect(result).to.be.bignumber.lt(maximum.mul(new BN('1000000')).div(new BN('999999')).toString())
            expect(result).to.be.bignumber.gt(maximum.mul(new BN('999999')).div(new BN('1000000')).toString())
          } else {
            // Easier to test prices diverging from 1
            expect(result).to.be.bignumber.lt(previousResult.toString())
          }
          previousResult = result
        }
      }
    })

    it('A lower g means more Dai in with `vyDaiInForFYDaiOut`', async () => {
      for (var i = 0; i < values.length; i++) {
        var daiReservesValue = values[i][0]
        var fyDaiReservesValue = values[i][1]
        var daiAmountValue = values[i][2]
        var timeTillMaturityValue = values[i][3]

        var daiReserves = toBigNumber(daiReservesValue)
        var fyDaiReserves = toBigNumber(fyDaiReservesValue)
        var daiAmount = toBigNumber(daiAmountValue)
        var timeTillMaturity = toBigNumber(timeTillMaturityValue)

        var g = [
          ['950', '1000'],
          ['95', '100'],
          ['9', '10'],
        ]
        var previousResult = new BN('0')
        for (var j = 0; j < g.length; j++) {
          var g_ = new BN(g[j][0]).mul(b).div(new BN(g[j][1]))
          var result = await yieldMath.vyDaiInForFYDaiOut(
            daiReserves,
            fyDaiReserves,
            daiAmount,
            timeTillMaturity,
            k,
            g_,
            ONE64
          )
        }

        expect(result).to.be.bignumber.gt(previousResult.toString())
        previousResult = result
      }
    })

    it('As we approach maturity, price drops to 1 for `vyDaiInForFYDaiOut`', async () => {
      for (var i = 0; i < values.length; i++) {
        // console.log("")
        var daiReservesValue = values[i][0]
        var fyDaiReservesValue = values[i][1]
        var daiAmountValue = values[i][2]

        var daiReserves = toBigNumber(daiReservesValue)
        var fyDaiReserves = toBigNumber(fyDaiReservesValue)
        var daiAmount = toBigNumber(daiAmountValue)

        const flatFee = new BN('1000000000000')
        const minimum = daiAmount.add(flatFee)
        var previousResult = minimum
        for (var j = 0; j < timeTillMaturity.length; j++) {
          var t = timeTillMaturity[j]
          var result = await yieldMath.vyDaiInForFYDaiOut(daiReserves, fyDaiReserves, daiAmount, t, k, g1, ONE64)

          // console.log("      " + result.toString())
          if (j == 0) {
            // Test that when we are very close to maturity, price is very close to 1 plus flat fee.
            expect(result).to.be.bignumber.gt(minimum.mul(new BN('999999')).div(new BN('1000000')).toString())
            expect(result).to.be.bignumber.lt(minimum.mul(new BN('1000000')).div(new BN('999999')).toString())
          } else {
            // Easier to test prices diverging from 1
            expect(result).to.be.bignumber.gt(previousResult.toString())
          }
          previousResult = result
        }
      }
    })
  })
})
