// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;
import "../pool/YieldMath.sol";
import "../pool/ABDKMath64x64.sol";


contract CryticTestYieldMath {
    uint128 internal oneDAI = 10**18;
    uint128 internal tol = oneDAI;
    int128 constant internal k = int128(uint256((1 << 64)) / 126144000); // 1 / Seconds in 4 years, in 64.64
    int128 constant internal g = int128(uint256((999 << 64)) / 1000); // All constants are `ufixed`, to divide them they must be converted to uint256

    uint128 minDaiReserves = 10**21; // $1000
    uint128 minYDaiReserves = 10**21; // $1000
    uint128 minTrade = 10**18; // $1
    uint128 minTimeTillMaturity = 1;
    uint128 maxDaiReserves = 10**27; // $1B
    uint128 maxYDaiReserves = 10**27; // $1B
    uint128 maxTrade = 10**26; // $100M
    uint128 maxTimeTillMaturity = uint128(k);

    constructor() public {}
    
    function greaterWithTol(uint256 x, uint256 y) internal view returns (bool) {
        return (x > y + tol); 
    }
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

    function testLiquidityInvariant(uint128 daiReserves, uint128 yDAIReserves, uint128 daiIn, uint128 timeTillMaturity) public view {
        daiReserves = minDaiReserves + daiReserves % maxDaiReserves;
        yDAIReserves = minYDaiReserves + yDAIReserves % maxYDaiReserves;
        daiIn = minTrade + daiIn % maxTrade;
        timeTillMaturity = minTimeTillMaturity + timeTillMaturity % maxTimeTillMaturity;

        uint256 reservesBefore = initialReservesValue(daiReserves, yDAIReserves, timeTillMaturity);
        uint128 yDaiOut = YieldMath.yDaiOutForDaiIn(daiReserves, yDAIReserves, daiIn, timeTillMaturity, k, g);
        uint256 reservesAfter = initialReservesValue(add(daiReserves, daiIn), sub(yDAIReserves, yDaiOut), add(timeTillMaturity, 1));
        assert(greaterWithTol(reservesAfter, reservesBefore));
    }

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
    internal pure returns (uint128) {
        // a = (1 - k * timeTillMaturity)
        int128 a = ABDKMath64x64.sub (0x10000000000000000, ABDKMath64x64.mul (k, ABDKMath64x64.fromUInt (timeTillMaturity)));
        require (a > 0);

        uint256 sum =
        uint256 (YieldMath.pow (daiReserves, uint128 (a), 0x10000000000000000)) +
        uint256 (YieldMath.pow (yDAIReserves, uint128 (a), 0x10000000000000000)) >> 1;
        require (sum < 0x100000000000000000000000000000000);

        uint256 result = uint256 (YieldMath.pow (uint128 (sum), 0x10000000000000000, uint128 (a))) << 1;
        require (result < 0x100000000000000000000000000000000);

        return uint128 (result);
    }
}