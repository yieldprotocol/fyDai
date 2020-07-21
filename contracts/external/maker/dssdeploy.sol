// SPDX-License-Identifier: AGPL-3.0-or-later
/// DssDeploy.sol

// Copyright (C) 2018-2020 Maker Ecosystem Growth Holdings, INC.

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.6.0;

import {Vat} from "./vat.sol";
import {Jug} from "./jug.sol";
import {DaiJoin} from "./join.sol";
import {Dai} from "./dai.sol";
import {End} from "./end.sol";
import {Pot} from "./pot.sol";
import {IDssDeploy} from "../../interfaces/IDssDeploy.sol";

contract VatFab {
    function newVat() public returns (Vat vat) {
        vat = new Vat();
        vat.rely(msg.sender);
        vat.deny(address(this));
    }
}

contract JugFab {
    function newJug(address vat) public returns (Jug jug) {
        jug = new Jug(vat);
        jug.rely(msg.sender);
        jug.deny(address(this));
    }
}

contract DaiFab {
    function newDai(uint chainId) public returns (Dai dai) {
        dai = new Dai(chainId);
        dai.rely(msg.sender);
        dai.deny(address(this));
    }
}

contract DaiJoinFab {
    function newDaiJoin(address vat, address dai) public returns (DaiJoin daiJoin) {
        daiJoin = new DaiJoin(vat, dai);
    }
}

contract PotFab {
    function newPot(address vat) public returns (Pot pot) {
        pot = new Pot(vat);
        pot.rely(msg.sender);
        pot.deny(address(this));
    }
}

contract EndFab {
    function newEnd() public returns (End end) {
        end = new End();
        end.rely(msg.sender);
        end.deny(address(this));
    }
}

contract DssDeploy is IDssDeploy {
    VatFab     public vatFab;
    JugFab     public jugFab;
    DaiFab     public daiFab;
    DaiJoinFab public daiJoinFab;
    PotFab     public potFab;
    EndFab     public endFab;

    Vat     public override vat;
    Jug     public override jug;
    Dai     public override dai;
    DaiJoin public override daiJoin;
    Pot     public override pot;
    End     public override end;

    constructor(
        VatFab vatFab_,
        JugFab jugFab_,
        DaiFab daiFab_,
        DaiJoinFab daiJoinFab_,
        PotFab potFab_,
        EndFab endFab_
    ) public {
        vatFab = vatFab_;
        jugFab = jugFab_;
        daiFab = daiFab_;
        daiJoinFab = daiJoinFab_;
        potFab = potFab_;
        endFab = endFab_;
    }

    function deployVat() public {
        vat = vatFab.newVat();
        vat.init("ETH-A");
    }

    function deployDai(uint256 chainId) public {
        require(address(vat) != address(0), "Missing previous step");

        // Deploy
        dai = daiFab.newDai(chainId);
        daiJoin = daiJoinFab.newDaiJoin(address(vat), address(dai));
        dai.rely(address(daiJoin));
    }

    function deployTaxation() public {
        require(address(vat) != address(0), "Missing previous step");

        // Deploy
        jug = jugFab.newJug(address(vat));
        pot = potFab.newPot(address(vat));

        // Internal
        vat.rely(address(jug));
        vat.rely(address(pot));
    }

    function deployShutdown() public {
        // Deploy
        end = endFab.newEnd();

        // Internal references set up
        end.file("vat", address(vat));
        end.file("pot", address(pot));

        // Internal
        vat.rely(address(end));
        pot.rely(address(end));
    }
}