const Faucet = artifacts.require('Faucet')

// @ts-ignore
import { expectRevert } from '@openzeppelin/test-helpers'
import { MakerEnvironment, Contract } from '../shared/fixtures'
import { toWad } from '../shared/utils'
import { assert } from 'chai'

contract('DecimalMath', async (accounts: string[]) => {
  let [owner] = accounts

  let vat: Contract
  let dai: Contract
  let weth: Contract
  let wethJoin: Contract
  let daiJoin: Contract
  let pot: Contract
  let chai: Contract
  let faucet: Contract

  beforeEach(async () => {
    const maker = await MakerEnvironment.setup()

    vat = maker.vat
    weth = maker.weth
    dai = maker.dai
    wethJoin = maker.wethJoin
    daiJoin = maker.daiJoin
    pot = maker.pot
    chai = maker.chai

    faucet = await Faucet.new(
      vat.address,
      weth.address,
      dai.address,
      wethJoin.address,
      daiJoin.address,
      pot.address,
      chai.address
    )
  })

  it('gets Weth', async () => {
    await faucet.getWeth(owner, toWad(1.23))
    assert.equal((await weth.balanceOf(owner)).toString(), toWad(1.23).toString())
  })

  it('doesn\'t give more than 1000 ETH', async () => {
    await expectRevert(
      faucet.getWeth(owner, toWad(1000.1)),
      "max 1000 eth"
    )
  })

  it('gets Dai', async () => {
    await faucet.getDai(owner, toWad(1.45))
    assert.equal((await dai.balanceOf(owner)).toString(), toWad(1.45).toString())
  })

  it('gets Chai', async () => {
    await faucet.getChai(owner, toWad(1.67))
    assert.equal((await chai.balanceOf(owner)).toString(), toWad(1.67).toString())
  })
})
