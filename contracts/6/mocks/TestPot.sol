pragma solidity ^0.6.2;

// avoid using interface to keep contract from being abstract
//import "./../interfaces/IPot.sol";


contract TestPot {
    uint256 internal _chi;  // the Rate Accumulator

    function chi() public view returns (uint256) {
        return _chi;
    }

    function set(uint256 chi_) public {
        _chi = chi_;
    }
}