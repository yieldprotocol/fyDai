pragma solidity ^0.6.2;

import "@hq20/contracts/contracts/math/DecimalMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IVat.sol";
import "./interfaces/IPot.sol";


///@dev yDai is a yToken targeting Dai
contract YDai is ERC20, Ownable() {
    using DecimalMath for uint256;
    using DecimalMath for uint8;

    constructor (string memory name, string memory symbol) 
        ERC20(name, symbol)
        public {
    }

    /// @dev Mint yDai. Only callable by its Controller contract.
    function mint(address user, uint256 amount) public onlyOwner {
        _mint(user, amount);
    }

    /// @dev Burn yDai. Only callable by its Controller contract.
    function burn(address user, uint256 amount) public onlyOwner {
        _burn(user, amount);
    }
}