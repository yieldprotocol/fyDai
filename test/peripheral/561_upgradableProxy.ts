const Pool = artifacts.require('Pool')

import { WETH, rate1, daiTokens1, wethTokens1, toWad, subBN, bnify, MAX, chainId, name, ZERO } from '../shared/utils'
import { MakerEnvironment, YieldEnvironmentLite, Contract } from '../shared/fixtures'
import { getSignatureDigest, getPermitDigest, getDaiDigest, userPrivateKey, sign } from '../shared/signatures'
import { setupProxy, upgradeToV2 } from '../shared/proxies'
import { keccak256, toUtf8Bytes } from 'ethers/lib/utils'

// @ts-ignore
import { expectRevert } from '@openzeppelin/test-helpers'
import { assert, expect } from 'chai'

contract('YieldProxy - DaiProxy', async (accounts) => {
  let [owner, user1, user2, operator] = accounts

  let maturity1: number
  let dai: Contract
  let controller: Contract
  let fyDai1: Contract
  let pool: Contract
  let daiProxy: Contract
  let maker: MakerEnvironment
  let env: YieldEnvironmentLite

  const one = toWad(1)
  const two = toWad(2)
  const fyDaiTokens1 = daiTokens1
  const fyDaiDebt = daiTokens1

  let digest: any

  beforeEach(async () => {
    const block = await web3.eth.getBlockNumber()
    maturity1 = (await web3.eth.getBlock(block)).timestamp + 31556952 // One year
    env = await YieldEnvironmentLite.setup([maturity1])
    maker = env.maker
    dai = env.maker.dai
    controller = env.controller

    fyDai1 = env.fyDais[0]

    // Setup Pool
    pool = await Pool.new(dai.address, fyDai1.address, 'Name', 'Symbol', { from: owner })

    // Setup DaiProxy
    daiProxy = await setupProxy(env.controller.address, [pool.address])

    // Allow owner to mint fyDai the sneaky way, without recording a debt in controller
    await fyDai1.orchestrate(owner, keccak256(toUtf8Bytes('mint(address,uint256)')), { from: owner })

    const deadline = MAX

    // Authorize the proxy for the controller
    digest = getSignatureDigest(
      name,
      controller.address,
      chainId,
      {
        user: user1,
        delegate: daiProxy.address,
      },
      await controller.signatureCount(user1),
      MAX
    )
    const controllerSig = sign(digest, userPrivateKey)

    // Authorize DAI
    digest = getDaiDigest(
      await dai.name(),
      dai.address,
      chainId,
      {
        owner: user1,
        spender: daiProxy.address,
        can: true,
      },
      bnify(await dai.nonces(user1)),
      deadline
    )
    let daiSig = sign(digest, userPrivateKey)

    // Send it! (note how it's not necessarily the user broadcasting it)
    await daiProxy.onboard(env.maker.dai.address, env.controller.address, user1, daiSig, controllerSig, {
      from: operator,
    })

    // Authorize the proxy for the pool
    digest = getSignatureDigest(
      name,
      pool.address,
      chainId,
      {
        user: user1,
        delegate: daiProxy.address,
      },
      bnify(await pool.signatureCount(user1)),
      MAX
    )
    const poolSig = sign(digest, userPrivateKey)

    // Authorize FYDai for the pool
    digest = getPermitDigest(
      await fyDai1.name(),
      await pool.fyDai(),
      chainId,
      {
        owner: user1,
        spender: daiProxy.address,
        value: MAX,
      },
      bnify(await fyDai1.nonces(user1)),
      MAX
    )
    const fyDaiSig = sign(digest, userPrivateKey)

    // Authorize DAI for the pool
    digest = getDaiDigest(
      await dai.name(),
      dai.address,
      chainId,
      {
        owner: user1,
        spender: pool.address,
        can: true,
      },
      bnify(await dai.nonces(user1)),
      deadline
    )
    const daiSig2 = sign(digest, userPrivateKey)
    // Send it!
    await daiProxy.authorizePool(pool.address, env.maker.dai.address, user1, daiSig2, fyDaiSig, poolSig, {
      from: operator,
    })
  })

  describe('with liquidity', () => {
    beforeEach(async () => {
      // Init pool
      const daiReserves = daiTokens1
      await env.maker.getDai(user1, daiReserves, rate1)
      await dai.approve(pool.address, MAX, { from: user1 })
      await fyDai1.approve(pool.address, MAX, { from: user1 })
      await pool.mint(user1, user1, daiReserves, { from: user1 })

      // Post some weth to controller via the proxy to be able to borrow
      // without requiring an `approve`!
      await daiProxy.post(user1, { from: user1, value: bnify(wethTokens1).mul(2).toString() })

      // Give some fyDai to user1
      await fyDai1.mint(user1, fyDaiTokens1, { from: owner })
    })

    describe('can be upgraded', async () => {
      const YieldProxy = artifacts.require('YieldProxy')
      let proxy: Contract

      beforeEach(async () => {
        proxy = await YieldProxy.at(daiProxy.address)
        daiProxy = await upgradeToV2(daiProxy)
      })

      it('returns the latest version', async () => {
        const ret = await proxy.getLatestVersion()
        expect(ret.toString()).to.eq('2')
      })

      it('can call new functions', async () => {
        const ret = await daiProxy.get()
        expect(ret.toString()).to.eq('123')
      })

      it('can call upgraded functions', async () => {
        const ret = await daiProxy.addLiquidity.call(pool.address, 0, 0)
        expect(ret.toString()).to.eq('42')
      })

      // this would call to weth which we did not explicitly
      // store in the new dai proxy
      it('can call old functions', async () => {
        await daiProxy.post(user1, { from: user1, value: bnify(wethTokens1).mul(2).toString() })
      })

      it('maintains `onboard` permissions', async () => {
        await daiProxy.post(user1, { from: user1, value: bnify(wethTokens1).mul(2).toString() })
        // `onboard` must be called in order to borrow. even though we
        // upgraded, we are still able to call the function without re-onboarding!
        await daiProxy.borrowDaiForMaximumFYDai(pool.address, WETH, maturity1, user2, fyDaiTokens1, one, {
          from: user1,
        })
      })

      it('maintains `authorizePool` permissions', async () => {
        // `authorizePool` must be called in order to borrow. even though we
        // upgraded, we are still able to call the function without re-authorizing!
        await daiProxy.borrowMinimumDaiForFYDai(pool.address, WETH, maturity1, user2, fyDaiTokens1, one, {
          from: user1,
        })
      })

      it('can choose old versions', async () => {
        await proxy.chooseVersion(1, { from: user1 })
        let ret = await daiProxy.addLiquidity.call(pool.address, 0, 0, { from: user1 })
        expect(ret.toString()).to.eq('0')

        await proxy.chooseVersion(2, { from: user1 })
        ret = await daiProxy.addLiquidity.call(pool.address, 0, 0, { from: user1 })
        expect(ret.toString()).to.eq('42')
      })

      it('cannot choose versions that have not been implemented yet', async () => {
        await expectRevert(
          proxy.chooseVersion(
            bnify(await proxy.getLatestVersion())
              .add(1)
              .toString(),
            { from: user1 }
          ),
          'YieldProxy: Invalid version'
        )
      })
    })
  })
})
