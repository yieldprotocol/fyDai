# YieldToken
YieldToken is an implementation of zero-coupon Dai bonds. It is inspired by the paper ["The Yield Protocol: On-Chain Lending With
Interest Rate Discovery"](https://yield.is/Yield.pdf) by Dan Robinson and Allan Niemerg.

The Yield specification can be found [here](https://docs.google.com/document/d/1TSc63v0E9X_aqmAL5VeIM1GDpALsf6yHiq0wGpfnsns/edit?usp=sharing).

## Warning
Legalese here. Also don't buy any fyDai governance token or interact with any contracts not listed on our deployments page.

## Install


### Pre Requisites
Before running any command, make sure to install dependencies:

```
$ yarn
```

### Lint Solidity
Lint the Solidity code:

```
$ yarn lint:sol
```

### Lint TypeScript
Lint the TypeScript code:

```
$ yarn lint:ts
```

### Coverage
Generate the code coverage report:

```
$ yarn coverage
```

### Test
Compile and test the smart contracts with [Buidler](https://buidler.dev/) and Mocha:

```
$ yarn test
```

### Fuzz
You will need to install [echidna](https://github.com/crytic/echidna) separately, and then run:

```
$ echidna-test . --contract WhitepaperInvariant --config contracts/invariants/config.yaml
```

### Start a local blockchain
We use [ganache](https://www.trufflesuite.com/ganache) as a local blockchain:

```
$ yarn ganache
```

### Start a local copy of the mainnet blockchain
We use [ganache](https://www.trufflesuite.com/ganache) to fork the mainnet blockchain:

```
$ yarn mainnet-ganache
```

### Migrate
We use [truffle](https://www.trufflesuite.com/) for migrations, make sure that `truffle-config.js` suits your use case, start a local ganache instance as explained above, and then run truffle:

```
$ npx truffle migrate
```

or

```
$ npx truffle migrate --network mainnet-ganache
```

## Architecture
A quick description of the deployment environment and the permissions given across the contracts in this repository can be found [here](https://docs.google.com/document/d/1BLh-CgoUIAFuB3aLcy2cbOLAMZyKcxN39HaHCb_KdBY/edit?usp=sharing)

## Math
In developing fyDai we have used two different libraries for fixed point arithmetic.
 - For general use we have forked and refined [DecimalMath.sol](https://github.com/HQ20/contracts/tree/master/contracts/math), trading off performance for clarity.
 - For heavy-duty use in the YieldSpace formula, we have relicensed [ABDKMath](https://github.com/abdk-consulting/abdk-libraries-solidity) as GPLv3, trading off clarity for performance.

## Security
In developing the code in this repository we have set the highest bar possible for security. 

We have been fully audited by [Trail of Bits](https://www.trailofbits.com/), with the results publicly available.

We have pioneered the use of fuzzing tests for the Pool and YieldMath contracts, allowing us to find edge cases and vulnerabilities that we would have missed otherwise.

Finally, we have had the repository independently reviewed by Sam Sun from Paradigm, revealing the final bugs that were lurking in the code.

## Contributing
This project doesn't include any governance or upgradability features. If you have a contribution to make, please reach us out on Discord and we will consider it for a future release or product.

## Acknowledgements
We would like to thank Dan Robinson (Paradigm), Georgios Konstantopoulos (Paradigm) and Sam Sun (Paradigm) for their tireless support, Mikhail Vladimirov (ABDK) for his genius, Gustavo Grieco (Trail of Bits) for his diligence, Martin Lundfall (dAppHub) for his kind feedback, and Noah Zinsmeister (Uniswap) for his advice towards the frontend delivery. We wouldn't be here without them.

## License
All files in this repository are released under the [GPLv3](https://github.com/yieldprotocol/fyDai/blob/master/LICENSE.md) license.
