// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

import "../interfaces/ITreasury.sol";
import "../interfaces/IYDai.sol";
import "../interfaces/IController.sol";
import "../interfaces/ILiquidations.sol";

/// @dev This contract allows to call privileged functions on Treasury
contract OrchestratedTreasuryMock {

    ITreasury public _treasury;

    constructor (address treasury_) public {
        _treasury = ITreasury(treasury_);
    }

    function pushDai(address user, uint256 dai) public { _treasury.pushDai(user, dai); }
    function pullDai(address user, uint256 dai) public { _treasury.pullDai(user, dai); }
    function pushChai(address user, uint256 chai) public { _treasury.pushChai(user, chai); }
    function pullChai(address user, uint256 chai) public { _treasury.pullChai(user, chai); }
    function pushWeth(address user, uint256 weth) public { _treasury.pushWeth(user, weth); }
    function pullWeth(address user, uint256 weth) public { _treasury.pullWeth(user, weth); }
}

/// @dev This contract allows to call privileged functions on YDai
contract OrchestratedYDaiMock {

    IYDai public _yDai;

    constructor (address yDai_) public {
        _yDai = IYDai(yDai_);
    }

    function mint(address user, uint256 amount) public { _yDai.mint(user, amount); }
}

/// @dev This contract allows to call privileged functions on Controller
contract OrchestratedControllerMock {

    IController public _controller;

    constructor (address controller_) public {
        _controller = IController(controller_);
    }
}

/// @dev This contract allows to call privileged functions on Liquidations
contract OrchestratedLiquidationsMock {

    ILiquidations public _liquidations;

    constructor (address liquidations_) public {
        _liquidations = ILiquidations(liquidations_);
    }

    function erase(address vault) public returns(uint128, uint128) { _liquidations.erase(vault); }
}