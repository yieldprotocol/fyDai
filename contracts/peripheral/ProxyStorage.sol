// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

import "../interfaces/IWeth.sol";
import "../interfaces/IDai.sol";
import "../interfaces/IGemJoin.sol";
import "../interfaces/IDaiJoin.sol";
import "../interfaces/IVat.sol";
import "../interfaces/IPot.sol";
import "../interfaces/IPool.sol";
import "../interfaces/IFYDai.sol";
import "../interfaces/IChai.sol";
import "../interfaces/IDelegable.sol";
import "../interfaces/ITreasury.sol";

interface ControllerLike is IDelegable {
    function treasury() external view returns (ITreasury);
    function series(uint256) external view returns (IFYDai);
    function seriesIterator(uint256) external view returns (uint256);
    function totalSeries() external view returns (uint256);
    function containsSeries(uint256) external view returns (bool);
    function posted(bytes32, address) external view returns (uint256);
    function locked(bytes32, address) external view returns (uint256);
    function debtFYDai(bytes32, uint256, address) external view returns (uint256);
    function debtDai(bytes32, uint256, address) external view returns (uint256);
    function totalDebtDai(bytes32, address) external view returns (uint256);
    function isCollateralized(bytes32, address) external view returns (bool);
    function inDai(bytes32, uint256, uint256) external view returns (uint256);
    function inFYDai(bytes32, uint256, uint256) external view returns (uint256);
    function erase(bytes32, address) external returns (uint256, uint256);
    function shutdown() external;
    function post(bytes32, address, address, uint256) external;
    function withdraw(bytes32, address, address, uint256) external;
    function borrow(bytes32, uint256, address, address, uint256) external;
    function repayFYDai(bytes32, uint256, address, address, uint256) external returns (uint256);
    function repayDai(bytes32, uint256, address, address, uint256) external returns (uint256);
}

// V1 Proxy Storage. V2 or more should inherit this.
contract ProxyStorage {
    IVat public vat;
    IWeth public weth;
    IDai public dai;
    IGemJoin public wethJoin;
    IDaiJoin public daiJoin;
    IChai public chai;
    ControllerLike public controller;
    ITreasury public treasury;

    IPool[] public pools;
    mapping (address => bool) public poolsMap;

    bytes32 public constant CHAI = "CHAI";
    bytes32 public constant WETH = "ETH-A";
    bool constant public MTY = true;
    bool constant public YTM = false;

    // ABI helpers for integrating with the authorization
    // logic in the main proxy
    function onboard(address,address,address,bytes memory,bytes memory) external {}
    function authorizePool(address, address, address, bytes memory, bytes memory, bytes memory) public {}
}
