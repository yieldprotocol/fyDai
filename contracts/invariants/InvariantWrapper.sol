// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;
import "./TradeReversalInvariant.sol";
import "./WhitepaperInvariant.sol";
import "./StatefulInvariant.sol";


contract TradeReversalInvariantWrapper is TradeReversalInvariant {

    /// @dev Sell fyDai and sell the obtained Dai back for fyDai
    function sellFYDaiAndReverse(uint128 daiReserves, uint128 fyDaiReserves, uint128 fyDaiIn, uint128 timeTillMaturity)
        public pure returns (uint128)
    {
        return _sellFYDaiAndReverse(daiReserves, fyDaiReserves, fyDaiIn, timeTillMaturity);
    }

    /// @dev Buy fyDai and sell it back
    function buyFYDaiAndReverse(uint128 daiReserves, uint128 fyDaiReserves, uint128 fyDaiOut, uint128 timeTillMaturity)
        public pure returns (uint128)
    {
        return _buyFYDaiAndReverse(daiReserves, fyDaiReserves, fyDaiOut, timeTillMaturity);
    }

    /// @dev Sell fyDai and sell the obtained Dai back for fyDai
    function sellDaiAndReverse(uint128 daiReserves, uint128 fyDaiReserves, uint128 daiIn, uint128 timeTillMaturity)
        public pure returns (uint128)
    {
        return _sellDaiAndReverse(daiReserves, fyDaiReserves, daiIn, timeTillMaturity);
    }

    /// @dev Buy fyDai and sell it back
    function buyDaiAndReverse(uint128 daiReserves, uint128 fyDaiReserves, uint128 daiOut, uint128 timeTillMaturity)
        public pure returns (uint128)
    {
        return _buyDaiAndReverse(daiReserves, fyDaiReserves, daiOut, timeTillMaturity);
    }
}

contract WhitepaperInvariantWrapper is WhitepaperInvariant {
    /// @dev Calculates the value of the reserves
    function whitepaperInvariant(uint128 daiReserves, uint128 fyDaiReserves, uint128 timeTillMaturity)
        public pure returns (uint128)
    {
        return _whitepaperInvariant(daiReserves, fyDaiReserves, timeTillMaturity);
    }
}

contract StatefulInvariantWrapper is StatefulInvariant {
    /// @dev Calculates the value of the reserves
    function whitepaperInvariant()
        public view returns (uint128)
    {
        return _whitepaperInvariant();
    }

    function getPool() public returns (address) {
        return address(pool);
    }

    function getDai() public returns (address) {
        return address(dai);
    }

    function getFYDai() public returns (address) {
        return address(fyDai);
    }
}