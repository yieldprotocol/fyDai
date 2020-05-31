const fixed_addrs = require('./fixed_addrs.json');
const Pot = artifacts.require("Pot");
const Vat = artifacts.require("Vat");
const GemJoin = artifacts.require("GemJoin");
const DaiJoin = artifacts.require("DaiJoin");
const Chai = artifacts.require("Chai");

const Treasury = artifacts.require("Treasury");
const ChaiOracle = artifacts.require("ChaiOracle");
const WethOracle = artifacts.require("WethOracle");

const Migrations = artifacts.require("Migrations");

const admin = require('firebase-admin');
let serviceAccount = require('../firebaseKey.json');
try {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://yield-ydai.firebaseio.com"
  });
} catch (e) { console.log(e)}

async function seriesToDb(seriesArr, sysContracts, networkId) {
  let db = admin.firestore();
  var batch = db.batch()
  seriesArr.forEach((doc) => {
    let docRef = db.collection(networkId.toString()).doc(doc.name);
    batch.set(docRef, doc);
  });
  let sysRef = db.collection(networkId.toString()).doc('sysAddrList')
  batch.set(sysRef, sysContracts);
  await batch.commit();
}

module.exports = async (deployer, network, accounts) => {

  console.log( process.argv )

  const migration = await Migrations.deployed();
  let vatAddress;
  let wethAddress;
  let wethJoinAddress;
  let daiAddress;
  let daiJoinAddress;
  let potAddress;
  let chaiAddress;
  let treasuryAddress;
  let chaiOracleAddress;
  let wethOracleAddress;

  if (network !== 'development') {
    vatAddress = fixed_addrs[network].vatAddress ;
    wethAddress = fixed_addrs[network].wethAddress;
    wethJoinAddress = fixed_addrs[network].wethJoinAddress;
    daiAddress = fixed_addrs[network].daiAddress;
    daiJoinAddress = fixed_addrs[network].daiJoinAddress;
    potAddress = fixed_addrs[network].potAddress;
    fixed_addrs[network].chaiAddress ? 
      (chaiAddress = fixed_addrs[network].chaiAddress)
      : (chaiAddress = (await Chai.deployed()).address);
 } else {
    vatAddress = (await Vat.deployed()).address;
    wethAddress = await migration.contracts.call('weth', (e,r)=> !e && r)
    wethJoinAddress = (await GemJoin.deployed()).address;
    daiAddress = await migration.contracts.call('dai', (e,r)=> !e && r)
    daiJoinAddress = (await DaiJoin.deployed()).address;
    potAddress = (await Pot.deployed()).address;
    chaiAddress = (await Chai.deployed()).address;
 }

 treasury = await Treasury.deployed();
 treasuryAddress = treasury.address;
 chaiOracleAddress = (await ChaiOracle.deployed()).address
 wethOracleAddress = (await WethOracle.deployed()).address;

  // Setup yDai - TODO: Replace by the right maturities, there will be several of these
  const YDai = artifacts.require("YDai");
  const Mint = artifacts.require("Mint");
  const ChaiDealer = artifacts.require("ChaiDealer");
  const WethDealer = artifacts.require("WethDealer");

  // const block = await web3.eth.getBlockNumber();
  const maturitiesInput = new Set([
    // [(await web3.eth.getBlock(block)).timestamp + 1000, 'Name1','Symbol1'],
    [1601510399, 'yDai-2020-09-30', 'yDai-2020-09-30'],
    [1609459199, 'yDai-2020-12-31', 'yDai-2020-12-31'],
    [1617235199, 'yDai-2021-03-31', 'yDai-2021-03-31'],
    [1625097599, 'yDai-2021-06-30', 'yDai-2021-06-30'],
  ]);

  const maturitiesOutput = [];

  for (const [maturity, name, symbol] of maturitiesInput.values()) {
    // Setup YDai
    await deployer.deploy(
      YDai,
      vatAddress,
      potAddress,
      maturity,
      name,
      symbol,
      { gas: 5000000 },
    );
    const yDai = await YDai.deployed();
    const yDaiAddress = yDai.address;

    // Setup mint
    await deployer.deploy(
      Mint,
      treasuryAddress,
      daiAddress,
      yDaiAddress,
      { gas: 5000000 },
    );
    const mint = await Mint.deployed();
    await yDai.grantAccess(mint.address);
    await treasury.grantAccess(mint.address);

    // Setup ChaiDealer
    await deployer.deploy(
      ChaiDealer,
      treasuryAddress,
      daiAddress,
      yDaiAddress,
      chaiAddress,
      chaiOracleAddress,
      { gas: 5000000 },
    );
    const chaiDealer = await ChaiDealer.deployed();
    await yDai.grantAccess(chaiDealer.address);
    await treasury.grantAccess(chaiDealer.address);
  
    // Setup WethDealer
    await deployer.deploy(
      WethDealer,
      treasuryAddress,
      daiAddress,
      yDaiAddress,
      wethAddress,
      wethOracleAddress,
      { gas: 5000000 },
    );
    const wethDealer = await WethDealer.deployed();
    await yDai.grantAccess(wethDealer.address);
    await treasury.grantAccess(wethDealer.address);

    maturitiesOutput.push({
      maturity, 
      name, 
      symbol, 
      'YDai': yDai.address,
      'Mint': mint.address,
      'ChaiDealer': chaiDealer.address,
      'WethDealer': wethDealer.address,
    })
  }

  const sysAddrList = {
    'vat': vatAddress,
    'weth': wethAddress,
    'wethJoin': wethJoinAddress,
    'dai': daiAddress,
    'daijoin': daiJoinAddress,
    'pot': potAddress,
    'chai': chaiAddress,
    'treasury': treasuryAddress,
    'chaiOracle': chaiOracleAddress,
    'wethOracle': wethOracleAddress
  }

  const networkId = await web3.eth.net.getId();
  await seriesToDb(maturitiesOutput, sysAddrList, networkId);

  console.log(sysAddrList)
  console.log(maturitiesOutput);

};
