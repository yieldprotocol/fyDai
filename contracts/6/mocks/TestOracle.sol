pragma solidity ^0.6.2;

import "./../interfaces/IOracle.sol";


//Using fake contract instead of abstract for mocking
contract TestOracle is IOracle {
    uint256 internal price;

    function set(uint256 price_) public {
        price = price_;
    }

    function get() public override view returns (uint256) {
        return price;
    }
}
