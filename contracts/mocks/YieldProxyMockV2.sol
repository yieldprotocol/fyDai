pragma solidity ^0.6.10;

import { StorageV2 } from "./YieldProxyStorageV2.sol";
import "../peripheral/ProxyV1.sol";

// Inherits from V1 proxy, and exposes a new method
// as well as its own initializer
contract ProxyV2 is StorageV2, ProxyV1 {
    function init(uint256 _foo) external {
        require(_foo > 0, "foo must be zero");
        require(
            foo == 0,
            "foo already initialized to non zero value"
        );
        foo = _foo;

    }

    function get() external view returns (uint) {
        return foo;
    }
}
