// Script used to log all liquidation events so far
//
// Run as node liquidation_history.js
// Requires having `ethers v5` installed.
//
// Provide arguments as environment variables:
// - ENDPOINT: The Ethereum node to connect to
// - LIQUIDATIONS: The address of the liquidations contract
// - START_BLOCK: The block to filter events from (default: 0).
//   Do not set this to 0 if using with services like Infura
const ethers = require('ethers')

// defaults to the infura node
const ENDPOINT = process.env.ENDPOINT || 'https://mainnet.infura.io/v3/878c2840dbf943898a8b60b5faef8fe9'
// uses the mainnet deployment
const LIQUIDATIONS = process.env.LIQUIDATIONS || '0x357B7E1Bd44f5e48b988a61eE38Bfe9a76983E33'
const START_BLOCK = process.env.START_BLOCK || 11065032 // deployed block

const ABI = [
    "event Liquidation(address indexed user, uint256 started, uint256 collateral, uint256 debt)",
]

const toDate = (ts)=> {
    const date = new Date(ts * 1000)
    return `${date.getMonth()}/${date.getFullYear()}`
}

;(async () => {
  const provider = new ethers.providers.JsonRpcProvider(ENDPOINT)
  const liquidations = new ethers.Contract(LIQUIDATIONS, ABI, provider)
  console.log(`Liquidation: ${liquidations.address}\n`)

    // Get all the times they posted and borrowed
  const liquidatedFilter = liquidations.filters.Liquidation();
  const logs = await liquidations.queryFilter(liquidatedFilter, START_BLOCK)
  const liquidated = logs.map((log) => {
      return {
          user: log.args.user.toString(),
          auction_start: toDate(log.args.started),
          debt: log.args.debt.toString(),
          collateral: log.args.collateral.toString(),
      }
  })
  console.log(liquidated)
})()
