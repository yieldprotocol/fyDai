// npx truffle exec --network [network] scripts/pool_liquidity.js --migrations [migrations contract address]
// If a network is not provided, it will check in the development one
// If a migrations address is not provided, it will look for the latest deployed instance

const { BN } = require('@openzeppelin/test-helpers')

const Migrations = artifacts.require('Migrations')
const Pool = artifacts.require('Pool')
const Vat = artifacts.require('Vat')
const Treasury = artifacts.require('Treasury')

const RAY = new BN('10').pow(new BN('27'))
const WAD = new BN('10').pow(new BN('18'))

function mulRay(x, ray) { return x.mul(ray).div(RAY) }

function divRay(x, ray) { return x.mul(RAY).div(ray) }

module.exports = async (deployer, network) => {
  let migrations
  if (process.argv.indexOf('--migrations') > -1)
    migrations = await Migrations.at(process.argv[process.argv.indexOf('--migrations') + 1])
  else 
    migrations = await Migrations.deployed()
  
  treasury = await Treasury.at(await migrations.contracts(web3.utils.fromAscii('Treasury')))
  vat = await Vat.at(await migrations.contracts(web3.utils.fromAscii('Vat')))

  const eth = (await vat.urns(web3.utils.fromAscii('ETH-A'), treasury.address)).ink
  const spot = (await vat.ilks(web3.utils.fromAscii('ETH-A'))).spot
  const collateral = mulRay(eth, spot)
  console.log(`Treasury Eth:   ${collateral.div(WAD)} (${eth.div(WAD)} Eth)`)

  const savings = await treasury.savings()
  const debt = await treasury.debt()
  console.log(`Treasury Dai:   ${savings.div(WAD)}`)
  console.log(`Treasury Debt:  ${debt.div(WAD)}`)

  let tvl = savings.add(collateral).sub(debt)
  const contracts = await migrations.length()
  for (let i = 0; i < contracts; i++) {
    const contractName = web3.utils.toAscii(await migrations.names(i))

    if (contractName.includes('fyDaiLP')) {
      const pool = await Pool.at(await migrations.contracts(web3.utils.fromAscii(contractName)))
      const dai = await pool.getDaiReserves()
      console.log(`${contractName}:   ${dai.div(WAD)}`)
      tvl = tvl.add(dai)
    }
  }
  console.log(`TVL:            ${tvl.div(WAD)}`)
  console.log('Press Ctrl+C to exit')
}
