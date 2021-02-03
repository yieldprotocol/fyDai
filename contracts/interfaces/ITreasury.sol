// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

import "@yield-protocol/utils/contracts/interfaces/weth/IWeth.sol";
import { VatAbstract } from "dss-interfaces/src/dss/VatAbstract.sol";
import "dss-interfaces/src/dss/DaiAbstract.sol";
import "dss-interfaces/src/dss/GemJoinAbstract.sol";
import "dss-interfaces/src/dss/DaiJoinAbstract.sol";
import "dss-interfaces/src/dss/PotAbstract.sol";
import "@yield-protocol/utils/contracts/interfaces/chai/IChai.sol";

interface ITreasury {
    function debt() external view returns(uint256);
    function savings() external view returns(uint256);
    function pushDai(address user, uint256 dai) external;
    function pullDai(address user, uint256 dai) external;
    function pushChai(address user, uint256 chai) external;
    function pullChai(address user, uint256 chai) external;
    function pushWeth(address to, uint256 weth) external;
    function pullWeth(address to, uint256 weth) external;
    function shutdown() external;
    function live() external view returns(bool);

    function vat() external view returns (VatAbstract);
    function weth() external view returns (IWeth);
    function dai() external view returns (DaiAbstract);
    function daiJoin() external view returns (DaiJoinAbstract);
    function wethJoin() external view returns (GemJoinAbstract);
    function pot() external view returns (PotAbstract);
    function chai() external view returns (IChai);
}
