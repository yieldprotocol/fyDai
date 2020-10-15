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
    IERC20 internal dai;
    IERC20 internal fyDai;
    Pool internal pool;

    uint128 constant internal precision = 1;
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

        pool.mint(address(this), address(this), 1e18); // Init the pools
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

    /// @dev Return the absolute difference between two numbers
    function diff(uint128 a, uint128 b) internal pure returns (uint128) {
        return (a > b) ? a - b : b - a;
    }

    /// @dev Ensure that the invariant changes when minting no more than `precision` 
    function mint(uint128 daiIn)
        public returns (uint128, uint128)
    {
        uint128 whitepaperInvariant_0 = _whitepaperInvariant();
        uint256 lpOut = pool.mint(address(this), address(this), daiIn);
        uint128 whitepaperInvariant_1 = _whitepaperInvariant();

        if(pool.getDaiReserves() > pool.getFYDaiReserves()) return (whitepaperInvariant_0, whitepaperInvariant_1); // Allow the transaction, but don't check the invariant.

        assert(diff(whitepaperInvariant_0, whitepaperInvariant_1) <= precision);
        return (whitepaperInvariant_0, whitepaperInvariant_1);
    }

    /// @dev Ensure that the invariant changes when burning no more than `precision` 
    function burn(uint128 lpIn)
        public returns (uint128, uint128)
    {
        uint128 whitepaperInvariant_0 = _whitepaperInvariant();
        (uint256 daiOut, uint256 fyDaiOut) = pool.burn(address(this), address(this), lpIn % (pool.balanceOf(address(this)) - 1)); // Never burn all
        uint128 whitepaperInvariant_1 = _whitepaperInvariant();

        if(pool.getDaiReserves() > pool.getFYDaiReserves()) return (whitepaperInvariant_0, whitepaperInvariant_1); // Allow the transaction, but don't check the invariant.

        assert(diff(whitepaperInvariant_0, whitepaperInvariant_1) <= precision);
        return (whitepaperInvariant_0, whitepaperInvariant_1);
    }

    /// @dev Ensures that reserves grow with any buyDai trade.
    function buyDai(uint128 daiOut)
        public returns (bool)
    {
        uint128 whitepaperInvariant_0 = _whitepaperInvariant();
        uint128 fyDaiIn = pool.buyDai(address(this), address(this), daiOut);
        uint128 whitepaperInvariant_1 = _whitepaperInvariant();

        if(pool.getDaiReserves() > pool.getFYDaiReserves()) return whitepaperInvariant_0 <= whitepaperInvariant_1; // Allow the transaction, but don't check the invariant.

        assert(whitepaperInvariant_0 <= whitepaperInvariant_1);
        return whitepaperInvariant_0 <= whitepaperInvariant_1;
    }

    /// @dev Ensures that reserves grow with any sellDai trade.
    function sellDai(uint128 daiIn)
        public returns (bool)
    {
        bool skipAssert = pool.getDaiReserves() > pool.getFYDaiReserves();

        uint128 whitepaperInvariant_0 = _whitepaperInvariant();
        uint128 fyDaiOut = pool.sellDai(address(this), address(this), daiIn);
        uint128 whitepaperInvariant_1 = _whitepaperInvariant();

        if (skipAssert) return whitepaperInvariant_0 <= whitepaperInvariant_1; // Allow the transaction, but don't check the invariant.

        assert(whitepaperInvariant_0 <= whitepaperInvariant_1);
        return whitepaperInvariant_0 <= whitepaperInvariant_1;
    }

    function _whitepaperInvariant ()
        internal view returns (uint128)
    {
        uint128 daiReserves = pool.getDaiReserves();
        uint128 fyDaiReserves = pool.getFYDaiReserves();
        uint128 timeTillMaturity = uint128(maturity - block.timestamp);
        uint256 supply = pool.totalSupply();
        require (supply < 0x100000000000000000000000000000000);
        
        // a = (1 - k * timeTillMaturity)
        int128 a = Math64x64.sub(0x10000000000000000, Math64x64.mul(k, Math64x64.fromUInt(timeTillMaturity)));
        require (a > 0);

        uint256 sum =
            uint256 (YieldMath128.pow(daiReserves, uint128(a), 0x10000000000000000)) +
            uint256 (YieldMath128.pow(fyDaiReserves, uint128(a), 0x10000000000000000)) >> 1;
        require (sum < 0x100000000000000000000000000000000);

        uint128 result = YieldMath128.pow(uint128(sum), 0x10000000000000000, uint128(a)) << 1;
        require (result < 0x100000000000000000000000000000000);

        result = uint128(Math64x64.div(int128(result), Math64x64.fromUInt(supply)));

        return result;
    }

    function _normalizedInvariant ()
        internal view returns (uint128)
    {
        uint128 daiReserves = pool.getDaiReserves();
        uint128 fyDaiReserves = pool.getFYDaiReserves();
        uint128 timeTillMaturity = uint128(maturity - block.timestamp);
        uint256 supply = pool.totalSupply();
        require (supply < 0x100000000000000000000000000000000);
        
        // a = (1 - k * timeTillMaturity)
        int128 a = Math64x64.sub(0x10000000000000000, Math64x64.mul(k, Math64x64.fromUInt(timeTillMaturity)));
        require (a > 0);

        uint256 sum =
            uint256 (YieldMath128.pow(daiReserves, uint128(a), 0x10000000000000000)) +
            uint256 (YieldMath128.pow(fyDaiReserves, uint128(a), 0x10000000000000000)) >> 1;
        require (sum < 0x100000000000000000000000000000000);

        uint128 result = YieldMath128.pow(uint128(sum), 0x10000000000000000, uint128(a)) << 1;
        require (result < 0x100000000000000000000000000000000);

        result = uint128(Math64x64.div(int128(result), Math64x64.fromUInt(supply)));

        return result;
    }
}