// Peripheral
const EthProxy = artifacts.require('EthProxy')

// @ts-ignore
import helper from 'ganache-time-traveler'
// @ts-ignore
import { balance } from '@openzeppelin/test-helpers'
import { WETH, CHAI, rate1, chi1, daiTokens1, wethTokens1, chaiTokens1 } from '../shared/utils'
import { Contract, YieldEnvironmentLite } from '../shared/fixtures'
import { getPermitDigest, getSignatureDigest, getChaiDigest } from '../shared/signatures'
import { defaultAbiCoder, keccak256, toUtf8Bytes } from 'ethers/lib/utils'
import { ecsign } from 'ethereumjs-util'

contract('Controller - EthProxy', async (accounts) => {
  let [owner, user1, user2] = accounts

  // this is the SECOND account that buidler creates
  // https://github.com/nomiclabs/buidler/blob/d399a60452f80a6e88d974b2b9205f4894a60d29/packages/buidler-core/src/internal/core/config/default-config.ts#L46
  const userPrivateKey = Buffer.from('d49743deccbccc5dc7baa8e69e5be03298da8688a15dd202e20f15d5e0e9a9fb', 'hex')
  const chainId = 31337 // buidlerevm chain id
  const name = 'Yield'
  const deadline = 100000000000000
  const emptySignature = Buffer.from('', 'hex')
  const SIGNATURE_TYPEHASH = keccak256(
    toUtf8Bytes('Signature(address user,address delegate,uint256 nonce,uint256 deadline)')
  )
  const PERMIT_TYPEHASH = keccak256(
    toUtf8Bytes('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)')
  )
  const CHAI_TYPEHASH = keccak256(
    toUtf8Bytes('Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)')
  )

  let signatureDigest: any
  let permitDigest: any

  let snapshot: any
  let snapshotId: string

  let vat: Contract
  let dai: Contract
  let chai: Contract
  let treasury: Contract
  let controller: Contract
  let ethProxy: Contract
  let weth: Contract

  let maturity1: number
  let maturity2: number

  beforeEach(async () => {
    snapshot = await helper.takeSnapshot()
    snapshotId = snapshot['result']

    const env = await YieldEnvironmentLite.setup()
    treasury = env.treasury
    controller = env.controller
    vat = env.maker.vat
    weth = env.maker.weth
    dai = env.maker.dai
    chai = env.maker.chai

    // Setup yDai
    const block = await web3.eth.getBlockNumber()
    maturity1 = (await web3.eth.getBlock(block)).timestamp + 1000
    maturity2 = (await web3.eth.getBlock(block)).timestamp + 2000
    await env.newYDai(maturity1, 'Name', 'Symbol')
    await env.newYDai(maturity2, 'Name', 'Symbol')

    // Setup EthProxy
    ethProxy = await EthProxy.new(weth.address, dai.address, chai.address, controller.address, { from: owner })
    
    // Create the signature digest
    const signatureStruct = {
      user: user1,
      delegate: ethProxy.address,
    }

    // Get the user's signatureCount
    const signatureCount = await controller.signatureCount(user1)

    // Get the EIP712 digest
    signatureDigest = getSignatureDigest(
      SIGNATURE_TYPEHASH,
      name,
      controller.address,
      chainId,
      signatureStruct,
      signatureCount,
      deadline
    )

    // Give some chai
    await env.maker.getChai(user1, chaiTokens1, chi1, rate1)
  })

  afterEach(async () => {
    await helper.revertToSnapshot(snapshotId)
  })

  it('allows user to post eth', async () => {
    assert.equal((await vat.urns(WETH, treasury.address)).ink, 0, 'Treasury has weth in MakerDAO')
    assert.equal(await controller.powerOf(WETH, user2), 0, 'User2 has borrowing power')

    const previousBalance = await balance.current(user1)
    await ethProxy.post(user2, wethTokens1, { from: user1, value: wethTokens1 })

    expect(await balance.current(user1)).to.be.bignumber.lt(previousBalance)
    assert.equal(
      (await vat.urns(WETH, treasury.address)).ink,
      wethTokens1.toString(),
      'Treasury should have weth in MakerDAO'
    )
    assert.equal(
      await controller.powerOf(WETH, user2),
      daiTokens1.toString(),
      'User2 should have ' + daiTokens1 + ' borrowing power, instead has ' + (await controller.powerOf(WETH, user2))
    )
  })

  it('allows user to post chai by signature', async () => {
    assert.equal(await chai.balanceOf(treasury.address), 0, 'Treasury has chai')
    assert.equal(await controller.powerOf(CHAI, user1), 0, 'User1 has borrowing power')

    
    // Delegate signature
    let delegateSignature: string
    {
      const { v, r, s } = ecsign(Buffer.from(signatureDigest.slice(2), 'hex'), userPrivateKey)
      delegateSignature = defaultAbiCoder.encode(['uint8', 'bytes32', 'bytes32'], [v, r, s])
    }

    const permitStruct = {
      holder: user1,
      spender: treasury.address,
      allowed: true,
    }

    // Permit signature
    // Get the user's nonce
    const permitCount = await chai.nonces(user1)

    // Get the EIP712 digest
    const chaiName = await chai.name()
    const chaiDigest = getChaiDigest(
      CHAI_TYPEHASH,
      chaiName,
      chai.address,
      chainId,
      permitStruct,
      permitCount,
      deadline
    )
    let chaiSignature: string
    {
      const { v, r, s } = ecsign(Buffer.from(chaiDigest.slice(2), 'hex'), userPrivateKey)
      chaiSignature = defaultAbiCoder.encode(['uint8', 'bytes32', 'bytes32'], [v, r, s])
    }
    
    await ethProxy.postChaiBySignature(user1, chaiTokens1, permitCount, deadline, delegateSignature, chaiSignature, { from: user1 })

    assert.equal(await chai.balanceOf(treasury.address), chaiTokens1.toString(), 'Treasury should have chai')
    assert.equal(
      await controller.powerOf(CHAI, user1),
      daiTokens1.toString(),
      'User1 should have ' + daiTokens1 + ' borrowing power, instead has ' + (await controller.powerOf(CHAI, user1))
    )
  })

  describe('with posted eth', () => {
    beforeEach(async () => {
      await ethProxy.post(user1, wethTokens1, { from: user1, value: wethTokens1 })

      assert.equal(
        (await vat.urns(WETH, treasury.address)).ink,
        wethTokens1.toString(),
        'Treasury does not have weth in MakerDAO'
      )
      assert.equal(await controller.powerOf(WETH, user1), daiTokens1.toString(), 'User1 does not have borrowing power')
      assert.equal(await weth.balanceOf(user2), 0, 'User2 has collateral in hand')
    })

    it('allows user to withdraw weth', async () => {
      await controller.addDelegate(ethProxy.address, { from: user1 })
      const previousBalance = await balance.current(user2)
      await ethProxy.withdraw(user2, wethTokens1, { from: user1 })

      expect(await balance.current(user2)).to.be.bignumber.gt(previousBalance)
      assert.equal((await vat.urns(WETH, treasury.address)).ink, 0, 'Treasury should not not have weth in MakerDAO')
      assert.equal(await controller.powerOf(WETH, user1), 0, 'User1 should not have borrowing power')
    })

    it('allows user to withdraw weth with an encoded signature', async () => {
      const { v, r, s } = ecsign(Buffer.from(signatureDigest.slice(2), 'hex'), userPrivateKey)

      const previousBalance = await balance.current(user2)
      await ethProxy.withdrawBySignature(user2, wethTokens1, deadline, v, r, s, { from: user1 })

      expect(await balance.current(user2)).to.be.bignumber.gt(previousBalance)
      assert.equal((await vat.urns(WETH, treasury.address)).ink, 0, 'Treasury should not not have weth in MakerDAO')
      assert.equal(await controller.powerOf(WETH, user1), 0, 'User1 should not have borrowing power')
    })
  })
})
