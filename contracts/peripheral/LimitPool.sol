// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../pool/Pool.sol";
import "../interfaces/IPool.sol";


/// @dev LimitPool is a proxy contract to Pool that implements limit orders.
contract LimitPool {

    /// @dev Sell Dai for yDai
    /// @param to Wallet receiving the yDai being bought
    /// @param daiIn Amount of dai being sold
    /// @param minYDaiOut Minimum amount of yDai being bought
    function sellDai(address pool, address to, uint128 daiIn, uint128 minYDaiOut)
        public
        returns(uint256)
    {
        uint256 yDaiOut = IPool(pool).sellDai(msg.sender, to, daiIn);
        require(
            yDaiOut >= minYDaiOut,
            "LimitPool: Limit not reached"
        );
        return yDaiOut;
    }

    /// @dev Sell Dai for yDai with an encoded signature for adding LimitPool as a delegate in Pool.
    /// @param pool Pool to trade in
    /// @param to Wallet receiving the yDai being bought
    /// @param daiIn Amount of dai being sold
    /// @param minYDaiOut Minimum amount of yDai being bought
    /// @param deadline Latest block timestamp for which the signature is valid
    /// @param signature ABI-encoded (uint8 v, bytes32 r, bytes32 s) signature
    function sellDaiBySignature(address pool, address to, uint128 daiIn, uint128 minYDaiOut, uint deadline, bytes calldata signature)
        public
        returns(uint256)
    {
        (uint8 v, bytes32 r, bytes32 s) = abi.decode(signature, (uint8, bytes32, bytes32));
        IPool(pool).addDelegateBySignature(msg.sender, address(this), deadline, v, r, s);
        return sellDai(pool, to, daiIn, minYDaiOut);
    }

    /// @dev Buy Dai for yDai
    /// @param to Wallet receiving the dai being bought
    /// @param daiOut Amount of dai being bought
    /// @param maxYDaiIn Maximum amount of yDai being sold
    function buyDai(address pool, address to, uint128 daiOut, uint128 maxYDaiIn)
        public
        returns(uint256)
    {
        uint256 yDaiIn = IPool(pool).buyDai(msg.sender, to, daiOut);
        require(
            maxYDaiIn >= yDaiIn,
            "LimitPool: Limit exceeded"
        );
        return yDaiIn;
    }

    /// @dev Buy Dai for yDai with an encoded signature for adding LimitPool as a delegate in Pool.
    /// @param pool Pool to trade in
    /// @param to Wallet receiving the dai being bought
    /// @param daiOut Amount of dai being bought
    /// @param maxYDaiIn Maximum amount of yDai being sold
    /// @param deadline Latest block timestamp for which the signature is valid
    /// @param v Signature parameter
    /// @param r Signature parameter
    /// @param s Signature parameter
    function buyDaiBySignature(address pool, address to, uint128 daiOut, uint128 maxYDaiIn, uint deadline, uint8 v, bytes32 r, bytes32 s)
        public
        returns(uint256)
    {
        IPool(pool).addDelegateBySignature(msg.sender, address(this), deadline, v, r, s);
        return buyDai(pool, to, daiOut, maxYDaiIn);
    }

    /// @dev Sell yDai for Dai
    /// @param to Wallet receiving the dai being bought
    /// @param yDaiIn Amount of yDai being sold
    /// @param minDaiOut Minimum amount of dai being bought
    function sellYDai(address pool, address to, uint128 yDaiIn, uint128 minDaiOut)
        public
        returns(uint256)
    {
        uint256 daiOut = IPool(pool).sellYDai(msg.sender, to, yDaiIn);
        require(
            daiOut >= minDaiOut,
            "LimitPool: Limit not reached"
        );
        return daiOut;
    }

    /// @dev Sell yDai for Dai with an encoded signature for adding LimitPool as a delegate in Pool.
    /// @param pool Pool to trade in
    /// @param to Wallet receiving the dai being bought
    /// @param yDaiIn Amount of yDai being sold
    /// @param minDaiOut Minimum amount of dai being bought
    /// @param deadline Latest block timestamp for which the signature is valid
    /// @param v Signature parameter
    /// @param r Signature parameter
    /// @param s Signature parameter
    function sellYDaiBySignature(address pool, address to, uint128 yDaiIn, uint128 minDaiOut, uint deadline, uint8 v, bytes32 r, bytes32 s)
        public
        returns(uint256)
    {
        IPool(pool).addDelegateBySignature(msg.sender, address(this), deadline, v, r, s);
        return sellYDai(pool, to, yDaiIn, minDaiOut);
    }

    /// @dev Buy yDai for dai
    /// @param to Wallet receiving the yDai being bought
    /// @param yDaiOut Amount of yDai being bought
    /// @param maxDaiIn Maximum amount of dai being sold
    function buyYDai(address pool, address to, uint128 yDaiOut, uint128 maxDaiIn)
        public
        returns(uint256)
    {
        uint256 daiIn = IPool(pool).buyYDai(msg.sender, to, yDaiOut);
        require(
            maxDaiIn >= daiIn,
            "LimitPool: Limit exceeded"
        );
        return daiIn;
    }

    /// @dev Buy yDai for dai with an encoded signature for adding LimitPool as a delegate in Pool.
    /// @param pool Pool to trade in
    /// @param to Wallet receiving the yDai being bought
    /// @param yDaiOut Amount of yDai being bought
    /// @param maxDaiIn Maximum amount of dai being sold
    /// @param deadline Latest block timestamp for which the signature is valid
    /// @param v Signature parameter
    /// @param r Signature parameter
    /// @param s Signature parameter
    function buyYDaiBySignature(address pool, address to, uint128 yDaiOut, uint128 maxDaiIn, uint deadline, uint8 v, bytes32 r, bytes32 s)
        public
        returns(uint256)
    {
        IPool(pool).addDelegateBySignature(msg.sender, address(this), deadline, v, r, s);
        return buyYDai(pool, to, yDaiOut, maxDaiIn);
    }
}