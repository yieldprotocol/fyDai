pragma solidity ^0.6.2;


interface ITreasury {
    function debt() external view returns(uint128);
    function savings() external returns(uint128);
    function pushDai(address user, uint128 dai) external;
    function pullDai(address user, uint128 dai) external;
    function pushChai(address user, uint128 chai) external;
    function pullChai(address user, uint128 chai) external;
    function pushWeth(address to, uint128 weth) external;
    function pullWeth(address to, uint128 weth) external;
    function shutdown() external;
    function live() external view returns(bool);
}