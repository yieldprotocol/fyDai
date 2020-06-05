pragma solidity ^0.6.2;


interface IGasToken {
    function mint(uint256) external;
    function free(uint256) external;
}