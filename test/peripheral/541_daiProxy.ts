const Pool = artifacts.require('Pool')
const DaiProxy = artifacts.require('YieldProxy')

import { WETH, wethTokens1, toWad, toRay, subBN, mulRay } from '../shared/utils'
import { YieldEnvironmentLite, Contract } from '../shared/fixtures'
import { getSignatureDigest } from '../shared/signatures'
import { keccak256, toUtf8Bytes } from 'ethers/lib/utils'
import { ecsign } from 'ethereumjs-util'

// @ts-ignore
import { expectRevert } from '@openzeppelin/test-helpers'
import { assert, expect } from 'chai'
import { BigNumber } from 'ethers'

contract('DaiProxy', async (accounts) => {
  let [owner, user1, user2, operator] = accounts

  // These values impact the pool results
  const rate1 = toRay(1.4)
  const daiDebt1 = toWad(96)
  const daiTokens1 = mulRay(daiDebt1, rate1)
  const yDaiTokens1 = daiTokens1

  let maturity1: number
  let weth: Contract
  let dai: Contract
  let treasury: Contract
  let controller: Contract
  let yDai1: Contract
  let pool: Contract
  let daiProxy: Contract
  let env: YieldEnvironmentLite

  const one = toWad(1)
  const two = toWad(2)
  const yDaiDebt = daiTokens1

  const MAX = BigNumber.from('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')
  const bnify = (num: any) => BigNumber.from(num.toString())

  beforeEach(async () => {
    env = await YieldEnvironmentLite.setup()
    weth = env.maker.weth
    dai = env.maker.dai
    treasury = env.treasury
    controller = env.controller

    // Setup yDai
    const block = await web3.eth.getBlockNumber()
    maturity1 = (await web3.eth.getBlock(block)).timestamp + 31556952 // One year
    yDai1 = await env.newYDai(maturity1, 'Name', 'Symbol')

    // Setup Pool
    pool = await Pool.new(dai.address, yDai1.address, 'Name', 'Symbol', { from: owner })

    // Setup DaiProxy
    daiProxy = await DaiProxy.new(env.controller.address, [pool.address])

    // Allow owner to mint yDai the sneaky way, without recording a debt in controller
    await yDai1.orchestrate(owner, keccak256(toUtf8Bytes('mint(address,uint256)')), { from: owner })

    // need delegate to the controller to send/post collateral
    await daiProxy.authorize({ from: user1 })
    await dai.approve(daiProxy.address, MAX, { from: user1 })
    await yDai1.approve(daiProxy.address, MAX, { from: user1 })
  })

  describe('with liquidity', () => {
    beforeEach(async () => {
      // Init pool
      const daiReserves = daiTokens1
      await env.maker.getDai(user1, daiReserves, rate1)
      await dai.approve(pool.address, MAX, { from: user1 })
      await yDai1.approve(pool.address, MAX, { from: user1 })
      await pool.init(daiReserves, { from: user1 })

      // Post some weth to controller to be able to borrow
      await weth.deposit({ from: user1, value: wethTokens1 })
      await weth.approve(treasury.address, wethTokens1, { from: user1 })
      await controller.post(WETH, user1, user1, wethTokens1, { from: user1 })

      // Give some yDai to user1
      await yDai1.mint(user1, yDaiTokens1, { from: owner })
    })

    it('borrows dai for maximum yDai', async () => {
      await daiProxy.borrowDaiForMaximumYDai(pool.address, WETH, maturity1, user2, yDaiTokens1, one, {
        from: user1,
      })

      assert.equal(await dai.balanceOf(user2), one.toString())
    })

    it("doesn't borrow dai if limit exceeded", async () => {
      await expectRevert(
        daiProxy.borrowDaiForMaximumYDai(pool.address, WETH, maturity1, user2, yDaiTokens1, daiTokens1, {
          from: user1,
        }),
        'DaiProxy: Too much yDai required'
      )
    })

    it('borrows minimum dai for yDai', async () => {
      const balanceBefore = bnify(await yDai1.balanceOf(user1))
      const balanceBefore2 = bnify(await dai.balanceOf(user2))
      await daiProxy.borrowMinimumDaiForYDai(pool.address, WETH, maturity1, user2, yDaiTokens1, one, {
        from: user1,
      })
      const balanceAfter = bnify(await yDai1.balanceOf(user1))
      const balanceAfter2 = bnify(await dai.balanceOf(user2))

      // user1's balance remains the same
      expect(balanceAfter.eq(balanceBefore)).to.be.true

      // user2 got >1 DAI
      expect(balanceAfter2.gt(balanceBefore2.add(one))).to.be.true
    })

    it("doesn't borrow dai if limit not reached", async () => {
      await expectRevert(
        daiProxy.borrowMinimumDaiForYDai(pool.address, WETH, maturity1, user2, one, daiTokens1, { from: user1 }),
        'DaiProxy: Not enough Dai obtained'
      )
    })

    describe('with extra yDai reserves', () => {
      beforeEach(async () => {
        // Set up the pool to allow buying yDai
        const additionalYDaiReserves = toWad(34.4)
        await yDai1.mint(operator, additionalYDaiReserves, { from: owner })
        await yDai1.approve(pool.address, additionalYDaiReserves, { from: operator })
        await pool.sellYDai(operator, operator, additionalYDaiReserves, { from: operator })

        // Create some yDai debt for `user2`
        await weth.deposit({ from: user2, value: wethTokens1 })
        await weth.approve(treasury.address, wethTokens1, { from: user2 })
        await controller.post(WETH, user2, user2, wethTokens1, { from: user2 })
        await controller.borrow(WETH, maturity1, user2, user2, daiTokens1, { from: user2 })

        // Give some Dai to `user1`
        await env.maker.getDai(user1, daiTokens1, rate1)
      })

      it('repays minimum yDai debt with dai', async () => {
        await dai.approve(pool.address, daiTokens1, { from: user1 })
        await daiProxy.repayMinimumYDaiDebtForDai(pool.address, WETH, maturity1, user2, one, two, {
          from: user1,
        })

        const debt = BigNumber.from((await controller.debtYDai(WETH, maturity1, user2)).toString())
        expect(debt.lt(yDaiDebt)).to.be.true
        assert.equal(await dai.balanceOf(user1), subBN(daiTokens1, two).toString())
      })

      it("doesn't repay debt if limit not reached", async () => {
        await expectRevert(
          daiProxy.repayMinimumYDaiDebtForDai(pool.address, WETH, maturity1, user2, two, one, { from: user1 }),
          'DaiProxy: Not enough yDai debt repaid'
        )
      })

      it('repays yDai debt with maximum dai', async () => {
        await daiProxy.repayYDaiDebtForMaximumDai(pool.address, WETH, maturity1, user2, one, two, {
          from: user1,
        })

        const balance = bnify(await dai.balanceOf(user1))
        expect(balance.lt(daiTokens1)).to.be.true
        assert.equal(await controller.debtYDai(WETH, maturity1, user2), subBN(yDaiDebt, one).toString())
      })

      it("doesn't repay debt if limit not reached", async () => {
        await expectRevert(
          daiProxy.repayYDaiDebtForMaximumDai(pool.address, WETH, maturity1, user2, two, one, { from: user1 }),
          'DaiProxy: Too much Dai required'
        )
      })
    })
  })
})
