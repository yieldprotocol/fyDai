// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

import {Vat} from "../external/maker/vat.sol";
import {Jug} from "../external/maker/jug.sol";
import {DaiJoin} from "../external/maker/join.sol";
import {Dai} from "../external/maker/dai.sol";
import {End} from "../external/maker/end.sol";
import {Pot} from "../external/maker/pot.sol";

interface IDssDeploy {
    function vat() external view returns (Vat);
    // function weth
    // function wethJoin
    function dai() external view returns (Dai);
    function daiJoin() external view returns (DaiJoin);
    function pot() external view returns (Pot);
    function jug() external view returns (Jug);
    function end() external view returns (End);
    // function chai
}