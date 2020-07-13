pragma solidity ^0.6.10;


interface IMarket {
    function sellChai(address from, address to, uint128 chaiIn) external returns(uint256);
    function buyChai(address from, address to, uint128 chaiOut) external returns(uint256);
    function sellYDai(address from, address to, uint128 yDaiIn) external returns(uint256);
    function buyYDai(address from, address to, uint128 yDaiOut) external returns(uint256);
    function sellChaiPreview(uint128 chaiIn) external view returns(uint256);
    function buyChaiPreview(uint128 chaiOut) external view returns(uint256);
    function sellYDaiPreview(uint128 yDaiIn) external view returns(uint256);
    function buyYDaiPreview(uint128 yDaiOut) external view returns(uint256);
}