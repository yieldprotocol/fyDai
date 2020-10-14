// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../pool/Math64x64.sol";
import "../pool/Pool.sol";
import "../pool/YieldMath.sol";     // 64 bits (for trading)
import "../mocks/YieldMath128.sol"; // 128 bits (for reserves calculation)
import "../mocks/TestERC20.sol";
import "../mocks/TestFYDai.sol";

import "@nomiclabs/buidler/console.sol";


contract StatefulInvariant {
    IERC20 public dai;
    IERC20 public fyDai;
    Pool public pool;

    uint128 constant internal precision = 1e12;
    int128 constant internal k = int128(uint256((1 << 64)) / 126144000); // 1 / Seconds in 4 years, in 64.64
    int128 constant internal g1 = int128(uint256((950 << 64)) / 1000); // To be used when selling Dai to the pool. All constants are `ufixed`, to divide them they must be converted to uint256
    int128 constant internal g2 = int128(uint256((1000 << 64)) / 950); // To be used when selling fyDai to the pool. All constants are `ufixed`, to divide them they must be converted to uint256

    uint128 minDaiReserves = 10**21; // $1000
    uint128 minFYDaiReserves = 10**21; // $1000
    uint128 minTrade = minDaiReserves / 1000; // $1
    uint128 minTimeTillMaturity = 0;
    uint128 maxDaiReserves = 10**27; // $1B
    uint128 maxFYDaiReserves = maxDaiReserves + 1; // $1B
    uint128 maxTrade = maxDaiReserves / 10;
    uint128 maxTimeTillMaturity = 31556952;

    uint256 maturity = block.timestamp + maxTimeTillMaturity;

    constructor() public {
        dai = IERC20(new TestERC20(type(uint256).max));
        fyDai = IERC20(new TestFYDai(type(uint256).max, maturity));
        pool = new Pool(address(dai), address(fyDai), "name", "symbol");

        dai.approve(address(pool), type(uint256).max);
        fyDai.approve(address(pool), type(uint256).max);
    }
    
    /// @dev Overflow-protected addition, from OpenZeppelin
    function add(uint128 a, uint128 b)
        internal pure returns (uint128)
    {
        uint128 c = a + b;
        require(c >= a, "Pool: Dai reserves too high");
        return c;
    }
    /// @dev Overflow-protected substraction, from OpenZeppelin
    function sub(uint128 a, uint128 b) internal pure returns (uint128) {
        require(b <= a, "Pool: fyDai reserves too low");
        uint128 c = a - b;
        return c;
    }

    /// @dev Ensures that reserves grow with any buyDai trade.
    function buyDai(uint128 daiOut)
        public returns (bool)
    {
        uint128 daiReserves = pool.getDaiReserves();
        uint128 fyDaiReserves = pool.getFYDaiReserves();
        uint128 timeTillMaturity = uint128(maturity - block.timestamp);

        uint128 whitepaperInvariant_0 = _whitepaperInvariant(daiReserves, fyDaiReserves, timeTillMaturity);
        uint128 fyDaiIn = pool.buyDai(address(this), address(this), daiOut);
        require(add(fyDaiReserves, fyDaiIn) >= sub(daiReserves, daiOut));
        uint128 whitepaperInvariant_1 = _whitepaperInvariant(sub(daiReserves, daiOut), add(fyDaiReserves, fyDaiIn), sub(timeTillMaturity, 1));
        assert(whitepaperInvariant_0 < whitepaperInvariant_1);
        return whitepaperInvariant_0 < whitepaperInvariant_1;
    }

    /// @dev Ensures that reserves grow with any sellDai trade.
    function sellDai(uint128 daiIn)
        public returns (bool)
    {
        uint128 daiReserves = pool.getDaiReserves();
        uint128 fyDaiReserves = pool.getFYDaiReserves();
        uint128 timeTillMaturity = uint128(maturity - block.timestamp);

        uint128 whitepaperInvariant_0 = _whitepaperInvariant(daiReserves, fyDaiReserves, timeTillMaturity);
        uint128 fyDaiOut = pool.sellDai(address(this), address(this), daiIn);
        require(sub(fyDaiReserves, fyDaiOut) >= add(daiReserves, daiIn));
        uint128 whitepaperInvariant_1 = _whitepaperInvariant(add(daiReserves, daiIn), sub(fyDaiReserves, fyDaiOut), sub(timeTillMaturity, 1));
        assert(whitepaperInvariant_0 < whitepaperInvariant_1);
        return whitepaperInvariant_0 < whitepaperInvariant_1;
    }

    /**
     * Estimate in DAI the value of reserves at protocol initialization time.
     *
     * @param daiReserves DAI reserves amount
     * @param fyDaiReserves fyDai reserves amount
     * @param timeTillMaturity time till maturity in seconds
     * @return estimated value of reserves
     */
    function _whitepaperInvariant (
        uint128 daiReserves, uint128 fyDaiReserves, uint128 timeTillMaturity)
        internal pure returns (uint128)
    {
        // a = (1 - k * timeTillMaturity)
        int128 a = Math64x64.sub (0x10000000000000000, Math64x64.mul (k, Math64x64.fromUInt (timeTillMaturity)));
        require (a > 0);

        uint256 sum =
        uint256 (YieldMath128.pow (daiReserves, uint128 (a), 0x10000000000000000)) +
        uint256 (YieldMath128.pow (fyDaiReserves, uint128 (a), 0x10000000000000000)) >> 1;
        require (sum < 0x100000000000000000000000000000000);

        uint256 result = uint256 (YieldMath128.pow (uint128 (sum), 0x10000000000000000, uint128 (a))) << 1;
        require (result < 0x100000000000000000000000000000000);

        return uint128 (result);
    }
}