// SPDX-License-Identifier: AGPL-3.0-or-later
/// pot.sol -- Dai Savings Rate

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
//
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

import './lib.sol';

/*
   "Savings Dai" is obtained when Dai is deposited into
   this contract. Each "Savings Dai" accrues Dai interest
   at the "Dai Savings Rate".
   This contract does not implement a user tradeable token
   and is intended to be used with adapters.
         --- `save` your `dai` in the `pot` ---
   - `dsr`: the Dai Savings Rate
   - `pie`: user balance of Savings Dai
   - `join`: start saving some dai
   - `exit`: remove some dai
   - `drip`: perform rate collection
*/

interface VatLike {
    function move(
        address,
        address,
        uint256
    ) external;

    function suck(
        address,
        address,
        uint256
    ) external;
}

contract Pot is LibNote {
    // --- Auth ---
    mapping(address => uint256) public wards;

    function rely(address guy) external note auth {
        wards[guy] = 1;
    }

    function deny(address guy) external note auth {
        wards[guy] = 0;
    }

    modifier auth {
        require(wards[msg.sender] == 1, 'Pot/not-authorized');
        _;
    }

    // --- Data ---
    mapping(address => uint256) public pie; // user Savings Dai

    uint256 public Pie; // total Savings Dai
    uint256 public dsr; // the Dai Savings Rate
    uint256 public chi; // the Rate Accumulator

    VatLike public vat; // CDP engine
    address public vow; // debt engine
    uint256 public rho; // time of last drip

    uint256 public live; // Access Flag

    // --- Init ---
    constructor(address vat_) public {
        wards[msg.sender] = 1;
        vat = VatLike(vat_);
        dsr = ONE;
        chi = ONE;
        rho = now;
        live = 1;
    }

    // --- Test ---
    /// @dev The dsr can be left at ONE so that calling `drip` doesn't change chi
    function setChi(uint256 chi_) public {
        chi = chi_;
    }

    // --- Math ---
    uint256 constant ONE = 10**27;

    function rpow(
        uint256 x,
        uint256 n,
        uint256 base
    ) internal pure returns (uint256 z) {
        assembly {
            switch x
                case 0 {
                    switch n
                        case 0 {
                            z := base
                        }
                        default {
                            z := 0
                        }
                }
                default {
                    switch mod(n, 2)
                        case 0 {
                            z := base
                        }
                        default {
                            z := x
                        }
                    let half := div(base, 2) // for rounding.
                    for {
                        n := div(n, 2)
                    } n {
                        n := div(n, 2)
                    } {
                        let xx := mul(x, x)
                        if iszero(eq(div(xx, x), x)) {
                            revert(0, 0)
                        }
                        let xxRound := add(xx, half)
                        if lt(xxRound, xx) {
                            revert(0, 0)
                        }
                        x := div(xxRound, base)
                        if mod(n, 2) {
                            let zx := mul(z, x)
                            if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) {
                                revert(0, 0)
                            }
                            let zxRound := add(zx, half)
                            if lt(zxRound, zx) {
                                revert(0, 0)
                            }
                            z := div(zxRound, base)
                        }
                    }
                }
        }
    }

    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = mul_(x, y) / ONE;
    }

    function add_(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    function sub_(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    function mul_(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    // --- Administration ---
    function file(bytes32 what, uint256 data) external note auth {
        require(live == 1, 'Pot/not-live');
        require(now == rho, 'Pot/rho-not-updated');
        if (what == 'dsr') dsr = data;
        else revert('Pot/file-unrecognized-param');
    }

    function file(bytes32 what, address addr) external note auth {
        if (what == 'vow') vow = addr;
        else revert('Pot/file-unrecognized-param');
    }

    function cage() external note auth {
        live = 0;
        dsr = ONE;
    }

    // --- Savings Rate Accumulation ---
    function drip() external note returns (uint256 tmp) {
        require(now >= rho, 'Pot/invalid-now');
        tmp = rmul(rpow(dsr, now - rho, ONE), chi);
        uint256 chi_ = sub_(tmp, chi);
        chi = tmp;
        rho = now;
        vat.suck(address(vow), address(this), mul_(Pie, chi_));
    }

    // --- Savings Dai Management ---
    function join(uint256 wad) external note {
        require(now == rho, 'Pot/rho-not-updated');
        pie[msg.sender] = add_(pie[msg.sender], wad);
        Pie = add_(Pie, wad);
        vat.move(msg.sender, address(this), mul_(chi, wad));
    }

    // --- Savings Dai Management ---
    function mockJoin(uint256 wad) external note {
        // require(now == rho, "Pot/rho-not-updated");
        pie[msg.sender] = add_(pie[msg.sender], wad);
        Pie = add_(Pie, wad);
        vat.move(msg.sender, address(this), mul_(chi, wad));
    }

    function exit(uint256 wad) external note {
        pie[msg.sender] = sub_(pie[msg.sender], wad);
        Pie = sub_(Pie, wad);
        vat.move(address(this), msg.sender, mul_(chi, wad));
    }
}
