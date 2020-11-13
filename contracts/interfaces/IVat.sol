// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

/// @dev Interface to interact with the vat contract from MakerDAO
/// Taken from https://github.com/makerdao/developerguides/blob/master/devtools/working-with-dsproxy/working-with-dsproxy.md
interface IVat {
    // function can(address, address) external view returns (uint);
    function hope(address) external;

    function nope(address) external;

    function live() external view returns (uint256);

    function ilks(bytes32)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        );

    function urns(bytes32, address) external view returns (uint256, uint256);

    function gem(bytes32, address) external view returns (uint256);

    // function dai(address) external view returns (uint);
    function frob(
        bytes32,
        address,
        address,
        address,
        int256,
        int256
    ) external;

    function fork(
        bytes32,
        address,
        address,
        int256,
        int256
    ) external;

    function move(
        address,
        address,
        uint256
    ) external;

    function flux(
        bytes32,
        address,
        address,
        uint256
    ) external;
}
