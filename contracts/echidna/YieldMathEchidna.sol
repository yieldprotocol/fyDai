// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;
import "../mocks/YieldMath64.sol";
import "../mocks/YieldMath128.sol";
import "../pool/YieldMath.sol"; // 48 bits
import "../pool/ABDKMath64x64.sol";
import "@nomiclabs/buidler/console.sol";


contract YieldMathEchidna {
    // uint128 constant internal precision = 10**27;
    int128 constant internal k = int128(uint256((1 << 64)) / 126144000); // 1 / Seconds in 4 years, in 64.64
    int128 constant internal g = int128(uint256((999 << 64)) / 1000); // All constants are `ufixed`, to divide them they must be converted to uint256

    uint128 minDaiReserves = 10**21; // $1000
    uint128 minYDaiReserves = minDaiReserves + 1;
    uint128 minTrade = minDaiReserves / 1000; // $1
    uint128 minTimeTillMaturity = 43200;
    uint128 maxDaiReserves = 10**27; // $1B
    uint128 maxYDaiReserves = maxDaiReserves + 1; // $1B
    uint128 maxTrade = maxDaiReserves / 10;
    uint128 maxTimeTillMaturity = 31556952;

    constructor() public {}
    
    /// @dev Bali Overflow-protected addition, from OpenZeppelin
    function add(uint128 a, uint128 b)
        internal pure returns (uint128)
    {
        uint128 c = a + b;
        require(c >= a, "Pool: Dai reserves too high");
        return c;
    }
    /// @dev Bali Overflow-protected substraction, from OpenZeppelin
    function sub(uint128 a, uint128 b) internal pure returns (uint128) {
        require(b <= a, "Pool: yDai reserves too low");
        uint128 c = a - b;
        return c;
    }

    function testLiquidityDaiOutForYDaiIn(uint128 daiReserves, uint128 yDAIReserves, uint128 yDaiIn, uint128 timeTillMaturity) public view returns (bool){
        if (daiReserves > yDAIReserves) return true;
        daiReserves = minDaiReserves + daiReserves % maxDaiReserves;
        yDAIReserves = minYDaiReserves + yDAIReserves % maxYDaiReserves;
        timeTillMaturity = minTimeTillMaturity + timeTillMaturity % maxTimeTillMaturity;

        uint128 reserves_0 = initialReservesValue(daiReserves, yDAIReserves, timeTillMaturity);
        uint128 daiOut= YieldMath128.daiOutForYDaiIn(daiReserves, yDAIReserves, yDaiIn, timeTillMaturity, k, g);
        uint128 reserves_1 = initialReservesValue(sub(daiReserves, daiOut), add(yDAIReserves, yDaiIn), sub(timeTillMaturity, 1));
        assert(reserves_0 < (reserves_1)); // + precision));
        return reserves_0 < (reserves_1); // + precision);
    }

    /*
    function testLiquidityDaiInForYDaiOut(uint128 daiReserves, uint128 yDAIReserves, uint128 yDaiOut, uint128 timeTillMaturity) public view returns (bool){
        if (daiReserves > yDAIReserves - yDaiOut) return true;
        daiReserves = minDaiReserves + daiReserves % maxDaiReserves;
        yDAIReserves = minYDaiReserves + yDAIReserves % maxYDaiReserves;
        timeTillMaturity = minTimeTillMaturity + timeTillMaturity % maxTimeTillMaturity;

        uint128 reserves_0 = initialReservesValue(daiReserves, yDAIReserves, timeTillMaturity);
        uint128 daiIn= YieldMath128.daiInForYDaiOut(daiReserves, yDAIReserves, yDaiOut, timeTillMaturity, k, g);
        uint128 reserves_1 = initialReservesValue(add(daiReserves, daiIn), sub(yDAIReserves, yDaiOut), sub(timeTillMaturity, 1));
        assert(reserves_0 < (reserves_1)); // + precision));
        return reserves_0 < (reserves_1); // + precision);
    }

    function testLiquidityYDaiOutForDaiIn(uint128 daiReserves, uint128 yDAIReserves, uint128 daiIn, uint128 timeTillMaturity) public view returns (bool){
        if (daiReserves + daiIn > yDAIReserves) return true;
        daiReserves = minDaiReserves + daiReserves % maxDaiReserves;
        yDAIReserves = minYDaiReserves + yDAIReserves % maxYDaiReserves;
        timeTillMaturity = minTimeTillMaturity + timeTillMaturity % maxTimeTillMaturity;

        uint128 reserves_0 = initialReservesValue(daiReserves, yDAIReserves, timeTillMaturity);
        uint128 yDaiOut= YieldMath128.yDaiOutForDaiIn(daiReserves, yDAIReserves, daiIn, timeTillMaturity, k, g);
        uint128 reserves_1 = initialReservesValue(add(daiReserves, daiIn), sub(yDAIReserves, yDaiOut), sub(timeTillMaturity, 1));
        assert(reserves_0 < (reserves_1)); // + precision));
        return reserves_0 < (reserves_1); // + precision);
    }

    function testLiquidityYDaiInForDaiOut(uint128 daiReserves, uint128 yDAIReserves, uint128 daiOut, uint128 timeTillMaturity) public view returns (bool){
        if (daiReserves > yDAIReserves) return true;
        daiReserves = minDaiReserves + daiReserves % maxDaiReserves;
        yDAIReserves = minYDaiReserves + yDAIReserves % maxYDaiReserves;
        timeTillMaturity = minTimeTillMaturity + timeTillMaturity % maxTimeTillMaturity;

        uint128 reserves_0 = initialReservesValue(daiReserves, yDAIReserves, timeTillMaturity);
        uint128 yDaiIn= YieldMath128.yDaiInForDaiOut(daiReserves, yDAIReserves, daiOut, timeTillMaturity, k, g);
        uint128 reserves_1 = initialReservesValue(sub(daiReserves, daiOut), add(yDAIReserves, yDaiIn), sub(timeTillMaturity, 1));
        assert(reserves_0 < (reserves_1)); // + precision));
        return reserves_0 < (reserves_1); // + precision);
    }
    */

    /*
    function testLog2MonotonicallyGrows(uint128 x) public view {
        uint128 z1= YieldMath128.log_2(x);
        uint128 z2= YieldMath128.log_2(x + 1);
        assert(z2 >= z1);
    }

    function testLog2PrecisionLossRoundsDown(uint128 x) public view {
        uint128 z1 = YieldMath.log_2(x);
        uint128 z2= YieldMath128.log_2(x);
        assert(z2 >= z1);
    }

    function testPow2PrecisionLossRoundsDown(uint128 x) public view {
        uint128 z1 = YieldMath.pow_2(x);
        uint128 z2= YieldMath128.pow_2(x);
        assert(z2 >= z1);
    } */

    /**
     * Estimate in DAI the value of reserves at protocol initialization time.
     *
     * @param daiReserves DAI reserves amount
     * @param yDAIReserves yDAI reserves amount
     * @param timeTillMaturity time till maturity in seconds
     * @return estimated value of reserves
     */
    function initialReservesValue (
        uint128 daiReserves, uint128 yDAIReserves, uint128 timeTillMaturity)
        public pure returns (uint128)
    {
        // a = (1 - k * timeTillMaturity)
        int128 a = ABDKMath64x64.sub (0x10000000000000000, ABDKMath64x64.mul (k, ABDKMath64x64.fromUInt (timeTillMaturity)));
        require (a > 0);

        uint256 sum =
        uint256 (YieldMath128.pow (daiReserves, uint128 (a), 0x10000000000000000)) +
        uint256 (YieldMath128.pow (yDAIReserves, uint128 (a), 0x10000000000000000)) >> 1;
        require (sum < 0x100000000000000000000000000000000);

        uint256 result = uint256 (YieldMath128.pow (uint128 (sum), 0x10000000000000000, uint128 (a))) << 1;
        require (result < 0x100000000000000000000000000000000);

        return uint128 (result);
    }
}