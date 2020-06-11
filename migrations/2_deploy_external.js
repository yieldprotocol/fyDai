// const { BN } = require('@openzeppelin/test-helpers');
const fixed_addrs = require('./fixed_addrs.json');
const ERC20 = artifacts.require("TestERC20");
const Vat = artifacts.require("Vat");
const Weth = artifacts.require("WETH9");
const GemJoin = artifacts.require("GemJoin");
const DaiJoin = artifacts.require("DaiJoin");
const Pot = artifacts.require("Pot");
const Migrations = artifacts.require("Migrations");

const { toWad, toRay, toRad, addBN, subBN, mulRay, divRay } = require('../test/shared/utils');

module.exports = async (deployer, network, accounts) => {
  const [owner] = accounts;
  let vatAddress;
  let wethAddress;
  let wethJoinAddress;
  let daiAddress;
  let daiJoinAddress;
  let potAddress;
  let chaiAddress;

  if (network === "development") {
    // Setting up Vat
    const ilk = web3.utils.fromAscii("ETH-A");
    const Line = web3.utils.fromAscii("Line");
    const spotName = web3.utils.fromAscii("spot");
    const linel = web3.utils.fromAscii("line");
    
    const limits = toRad(10000);
    const spot  = toRay(1.5);
    const rate  = toRay(1.25);
    const chi  = toRay(1.25);

    // Setup Vat, Dai, Join and Weth
    await deployer.deploy(Vat);
    const vat = await Vat.deployed();
    vatAddress = vat.address;
    await vat.rely(vatAddress);
    await vat.init(ilk, { from: owner });// Set ilk rate to 1.0

    await deployer.deploy(Weth, 0);
    wethAddress = (await Weth.deployed()).address;

    const migration = await Migrations.deployed();
    await migration.setDupAddr('weth', wethAddress );

    await deployer.deploy(GemJoin, vatAddress, ilk, wethAddress);
    wethJoinAddress = (await GemJoin.deployed()).address;
    await vat.rely(wethJoinAddress);

    await deployer.deploy(ERC20, 0);
    daiAddress = (await ERC20.deployed()).address;

    await migration.setDupAddr('dai', daiAddress );

    await deployer.deploy(DaiJoin, vatAddress, daiAddress);
    daiJoinAddress = (await DaiJoin.deployed()).address;

    // Setup spot and limits
    await vat.file(ilk, spotName, spot);
    await vat.file(ilk, linel, limits);
    await vat.file(Line, limits);
    await vat.fold(ilk, vat.address, subBN(rate, toRay(1))); // Fold only the increase from 1.0

    // Setup Pot
    await deployer.deploy(Pot, vatAddress);
    potAddress = (await Pot.deployed()).address;
    const pot = await Pot.deployed();
    await pot.setChi(chi);

    await vat.rely(vatAddress);
    await vat.rely(wethJoinAddress);
    await vat.rely(daiJoinAddress);
    await vat.rely(potAddress);
    await vat.hope(daiJoinAddress);
    await vat.hope(wethJoinAddress);

  };

   if (network !== 'development') {
      vatAddress = fixed_addrs[network].vatAddress ;
      wethAddress = fixed_addrs[network].wethAddress;
      wethJoinAddress = fixed_addrs[network].wethJoinAddress;
      daiAddress = fixed_addrs[network].daiAddress;
      daiJoinAddress = fixed_addrs[network].daiJoinAddress;
      potAddress = fixed_addrs[network].potAddress;
      fixed_addrs[network].chaiAddress && (chaiAddress = fixed_addrs[network].chaiAddress);
   };

  if (network !== "mainnet" && network !== "kovan" && network !== "kovan-fork") {
    const Chai = artifacts.require("Chai");
    // Setup Chai
    await deployer.deploy(
      Chai,
      vatAddress,
      potAddress,
      daiJoinAddress,
      daiAddress,
    );
    chaiAddress = (await Chai.deployed()).address;
  };
  
  console.log("    External contract addresses");
  console.log("    ---------------------------");
  console.log("    vat:      " + vatAddress);
  console.log("    weth:     " + wethAddress);
  console.log("    wethJoin: " + wethJoinAddress);
  console.log("    dai:      " + daiAddress);
  console.log("    daiJoin:  " + daiJoinAddress);
  console.log("    chai:     " + chaiAddress);
}


/// @dev Returns the decimals in a number
/* function decimals(value) {
  if(Math.floor(value) === value) return 0;
  return value.toString().split(".")[1].length || 0; 
}; */

/// @dev Converts a number to RAY precision
/* function toRay(value) {
  return web3.utils.toBN(value.toString()) * web3.utils.toBN('10').pow(new BN(27).sub(new BN(decimals(value.toString())))); 
}; */

/// @dev Converts a number to RAY precision
/* function toRad(value) {
  return web3.utils.toBN(value.toString()) * web3.utils.toBN('10').pow((new BN(45)).sub(new BN(decimals(value.toString())))); 
}; */

/// @dev Converts a string to bytes32
/* function stringToBytes32(text) {
  let result = web3.utils.fromAscii(text);
  while (result.length < 66) result += '0'; // 0x + 64 digits
  return result;
}; */

/// @dev Converts a bytes32 to string
/* function bytes32ToString(text) {
  return web3.utils.toAscii(text).replace(/\0/g, '');
}; */
