pragma solidity ^0.6.2;

//avoid interface to avoid making contract abstract
//import "./../interfaces/IVat.sol";


contract TestVat {
    uint256 internal _rate;

    function ilks(bytes32) external view returns (
        uint256,   // wad
        uint256 rate,  // ray
        uint256,  // ray
        uint256,  // rad
        uint256   // rad
    ){
        rate = _rate;
    }

    function set(uint256 rate_) public {
        _rate = rate_;
    }
}