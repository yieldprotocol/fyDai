// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

import "../peripheral/ProxyStorage.sol";

// Add a new storage var
contract StorageV2 is ProxyStorage {
    uint foo;
}
