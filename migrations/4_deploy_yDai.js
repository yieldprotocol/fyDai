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

module.exports = async (deployer, network, accounts) => {

  console.log( process.argv )

  const db = admin.firestore();
  const batch = db.batch();
  const networkId = await web3.eth.net.getId();

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

  let wethDealerAddress;
  let chaiDealerAddress;

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

      wethDealerAddress = await migration.contracts.call('wethDealer', (e,r)=> !e && r)
      chaiDealerAddress = await migration.contracts.call('chaiDealer', (e,r)=> !e && r)
  }

  treasury = await Treasury.deployed();
  treasuryAddress = treasury.address;
  chaiOracleAddress = (await ChaiOracle.deployed()).address
  wethOracleAddress = (await WethOracle.deployed()).address;

  // Setup yDai - TODO: Replace by the right maturities, there will be several of these
  const YDai = artifacts.require("YDai");
  const Dealer = artifacts.require("Dealer");
  const wethDealer = await Dealer.at(wethDealerAddress);
  const chaiDealer = await Dealer.at(chaiDealerAddress);

  // const block = await web3.eth.getBlockNumber();
  const maturitiesInput = new Set([
    // [(await web3.eth.getBlock(block)).timestamp + 1000, 'Name1','Symbol1'],
    [1601510399, 'yDai-2020-09-30', 'yDai-2020-09-30'],
    [1609459199, 'yDai-2020-12-31', 'yDai-2020-12-31'],
    [1617235199, 'yDai-2021-03-31', 'yDai-2021-03-31'],
    [1625097599, 'yDai-2021-06-30', 'yDai-2021-06-30'],
  ]);

  const deployedMaturities = [];
  for (const [maturity, name, symbol] of maturitiesInput.values()) {
    // Setup YDai
    await deployer.deploy(
      YDai,
      vatAddress,
      potAddress,
      treasuryAddress,
      maturity,
      name,
      symbol,
      { gas: 5000000 },
    );
    const yDai = await YDai.deployed();
    const yDaiAddress = yDai.address;
    await treasury.grantAccess(yDai.address);

    // Subscribe to WethDealer
    await wethDealer.addSeries(yDaiAddress);
    yDai.grantAccess(wethDealerAddress);
    // await treasury.grantAccess(wethDealer.address);

    // Subscribe to ChaiDealer
    await chaiDealer.addSeries(yDaiAddress);
    yDai.grantAccess(chaiDealerAddress);
    // await treasury.grantAccess(chaiDealer.address);

    deployedMaturities.push({
      maturity, 
      name, 
      symbol, 
      'YDai': yDai.address,
    })

    let maturityRef = db.collection(networkId.toString()).doc(name);
    batch.set(maturityRef, deployedMaturities[deployedMaturities.length -1]);
  }

  const deployedCore = {
    'Vat': vatAddress,
    'Weth': wethAddress,
    'WethJoin': wethJoinAddress,
    'Dai': daiAddress,
    'DaiJoin': daiJoinAddress,
    'Pot': potAddress,
    'Chai': chaiAddress,
    'WethOracle': wethOracleAddress,
    'ChaiOracle': chaiOracleAddress,
    'Treasury': treasuryAddress,
    'WethDealer' : wethDealerAddress,
    'ChaiDealer' : chaiDealerAddress,
  }

  let coreRef = db.collection(networkId.toString()).doc('deployedCore')
  batch.set(coreRef, deployedCore);
  await batch.commit();

  console.log(deployedCore)
  console.log(deployedMaturities);

};