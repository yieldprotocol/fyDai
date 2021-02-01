// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

import "../external/weth/interfaces/IWeth.sol";
import "../external/maker/interfaces/IVat.sol";
import "../external/maker/interfaces/IDai.sol";
import "../external/maker/interfaces/IGemJoin.sol";
import "../external/maker/interfaces/IDaiJoin.sol";
import "../external/maker/interfaces/IPot.sol";
import "../external/chai/interfaces/IChai.sol";

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

    function vat() external view returns (IVat);
    function weth() external view returns (IWeth);
    function dai() external view returns (IDai);
    function daiJoin() external view returns (IDaiJoin);
    function wethJoin() external view returns (IGemJoin);
    function pot() external view returns (IPot);
    function chai() external view returns (IChai);
}
