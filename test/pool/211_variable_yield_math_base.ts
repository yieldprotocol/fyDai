const VariableYieldMath = artifacts.require('VariableYieldMathWrapper')

// @ts-ignore
import helper from 'ganache-time-traveler'
import { Contract } from '../shared/fixtures'
// @ts-ignore
import { BN, expectRevert } from '@openzeppelin/test-helpers'

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

contract('VariableYieldMath - Base', async (accounts) => {
  let snapshot: any
  let snapshotId: string

  let yieldMath: Contract

  const ONE = '0x10000000000000000'

  beforeEach(async () => {
    snapshot = await helper.takeSnapshot()
    snapshotId = snapshot['result']

    // Setup VariableYieldMathDAIWrapper
    yieldMath = await VariableYieldMath.new()
  })

  afterEach(async () => {
    await helper.revertToSnapshot(snapshotId)
  })

  it('get the size of the contract', async () => {
    console.log()
    console.log('    ·--------------------|------------------|------------------|------------------·')
    console.log('    |  Contract          ·  Bytecode        ·  Deployed        ·  Constructor     |')
    console.log('    ·····················|··················|··················|···················')

    const bytecode = yieldMath.constructor._json.bytecode
    const deployed = yieldMath.constructor._json.deployedBytecode
    const sizeOfB = bytecode.length / 2
    const sizeOfD = deployed.length / 2
    const sizeOfC = sizeOfB - sizeOfD
    console.log(
      '    |  ' +
        yieldMath.constructor._json.contractName.padEnd(18, ' ') +
        '|' +
        ('' + sizeOfB).padStart(16, ' ') +
        '  ' +
        '|' +
        ('' + sizeOfD).padStart(16, ' ') +
        '  ' +
        '|' +
        ('' + sizeOfC).padStart(16, ' ') +
        '  |'
    )
    console.log('    ·--------------------|------------------|------------------|------------------·')
    console.log()
  })

  describe('Test pure math functions', async () => {
    it('Test `log_2` function', async () => {
      var xValues = [
        '0x0',
        '0x1',
        '0x2',
        '0xFEDCBA9876543210',
        '0xFFFFFFFFFFFFFFFF',
        '0x10000000000000000',
        '0xFFFFFFFFFFFFFFFFFFFFFFFF',
        '0x1000000000000000000000000',
        '0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
        '0x10000000000000000000000000000',
        '0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
        '0x1000000000000000000000000000000',
        '0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
        '0x10000000000000000000000000000000',
        '0x3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
        '0x40000000000000000000000000000000',
        '0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
        '0x80000000000000000000000000000000',
        '0xFEDCBA9876543210FEDCBA9876543210',
        '0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
      ]

      for (var i = 0; i < xValues.length; i++) {
        var xValue = xValues[i]
        // console.log('    log_2 (' + xValue + ')')
        var x = toBigNumber(xValue)
        var result
        try {
          result = await yieldMath.log_2(x)
        } catch (e) {
          result = [false, undefined]
        }
        if (!x.eq(toBigNumber('0x0'))) {
          assert('log_2 (' + xValue + ')[0]', result[0])
          assert(
            'log_2 (' + xValue + ')[1]',
            Math.abs(
              Math.log(Number(x)) / Math.LN2 -
                Number(result[1]) / Number(toBigNumber('0x2000000000000000000000000000000'))
            ) < 0.00000000001
          )
        } else {
          assert('!log_2 (' + xValue + ')[0]', !result[0])
        }
      }
    })

    it('Test `pow_2` function', async () => {
      var xValues = [
        '0x0',
        '0x1',
        '0x2',
        '0x1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
        '0x2000000000000000000000000000000',
        '0x2000000000000000000000000000001',
        '0x20123456789ABCDEF0123456789ABCD',
        '0x3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
        '0x40000000000000000000000000000000',
        '0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
        '0x80000000000000000000000000000000',
        '0xFEDCBA9876543210FEDCBA9876543210',
        '0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
      ]

      for (var i = 0; i < xValues.length; i++) {
        var xValue = xValues[i]
        // console.log('    pow_2 (' + xValue + ')')
        var x = toBigNumber(xValue)
        var result
        try {
          result = await yieldMath.pow_2(x)
        } catch (e) {
          result = [false, undefined]
        }
        assert('pow_2 (' + xValue + ')[0]', result[0])
        var expected = Math.pow(2, Number(x) / Number(toBigNumber('0x2000000000000000000000000000000')))
        assert(
          'pow_2 (' + xValue + ')[1]',
          Math.abs(expected - Number(result[1])) <= Math.max(1.0000000000001, expected / 1000000000000.0)
        )
      }
    })

    it('Test `pow` function', async () => {
      var xValues = ['0x0', '0x1', '0x2', '0xFEDCBA9876543210', '0xFEDCBA9876543210FEDCBA9876543210']
      var yzValues = [
        ['0x0', '0x0'],
        ['0x1', '0x0'],
        ['0x0', '0x1'],
        ['0x1', '0x1'],
        ['0x2', '0x1'],
        ['0x3', '0x1'],
        ['0x7F', '0x1'],
        ['0xFEDCBA987', '0x1'],
        ['0xFEDCBA9876543210FEDCBA9876543210', '0x1'],
        ['0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF', '0x1'],
        ['0x1', '0x2'],
        ['0x1', '0x3'],
        ['0x1', '0x7F'],
        ['0x1', '0xFEDCBA9876543210'],
        ['0x1', '0xFEDCBA9876543210FEDCBA9876543210'],
        ['0x1', '0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'],
      ]

      for (var i = 0; i < xValues.length; i++) {
        var xValue = xValues[i]
        for (var j = 0; j < yzValues.length; j++) {
          var yValue = yzValues[j][0]
          var zValue = yzValues[j][1]
          // console.log('    pow (' + xValue + ', ' + yValue + ', ' + zValue + ')')
          var x = toBigNumber(xValue)
          var y = toBigNumber(yValue)
          var z = toBigNumber(zValue)
          var result
          try {
            result = await yieldMath.pow(x, y, z)
          } catch (e) {
            result = [false, undefined]
          }

          if (!z.eq(toBigNumber('0x0')) && (!x.eq(toBigNumber('0x0')) || !y.eq(toBigNumber('0x0')))) {
            assert('pow (' + xValue + ', ' + yValue + ', ' + zValue + ')[0]', result[0])
            var expectedLog =
              (Math.log(Number(x)) * Number(y)) / Number(z) + 128 * (1.0 - Number(y) / Number(z)) * Math.LN2
            if (expectedLog < 0.0) expectedLog = -1.0
            if (x.eq(toBigNumber('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'))) expectedLog = 128 * Math.LN2
            var resultLog = Math.log(Number(result[1]))
            if (resultLog < 0.0) resultLog = -1.0
            assert(
              'pow (' + xValue + ', ' + yValue + ', ' + zValue + ')[1]',
              Math.abs(expectedLog - resultLog) <= 0.000000001
            )
          } else {
            assert('!pow (' + xValue + ', ' + yValue + ', ' + zValue + ')[0]', !result[0])
          }
        }
      }
    })
  })
})
