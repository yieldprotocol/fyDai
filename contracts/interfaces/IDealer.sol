pragma solidity ^0.6.2;

import "./IYDai.sol";


interface IDealer {
    function series(uint256) external returns (IYDai);
    function systemPosted(bytes32) external returns (uint128);
    function systemDebtYDai(bytes32, uint256) external returns (uint128);
    function posted(bytes32, address) external view returns (uint128);
    function totalDebtDai(bytes32, address) external returns (uint128);
    function isCollateralized(bytes32, address) external returns (bool);
    function grab(bytes32, address, uint128, uint128) external;
    function shutdown() external;
    function post(bytes32, address, address, uint128) external;
    function withdraw(bytes32, address, address, uint128) external;
}