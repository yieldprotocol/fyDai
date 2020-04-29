pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract TestERC20 is ERC20 {

    constructor (string memory name, string memory symbol, uint256 supply) 
    ERC20(name, symbol)
    public {
         _mint(msg.sender, supply);
    }
}