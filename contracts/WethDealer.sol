pragma solidity ^0.6.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ITreasury.sol";
import "./Constants.sol";
import "./ERC20Dealer.sol";


/// @dev A WethDealer takes weth as collateral and issues yDai. Weth is posted to MakerDAO through the Treasury.
contract WethDealer is ERC20Dealer {

    constructor (
        address treasury_,
        address dai_,
        address yDai_,
        address gasToken_,
        address weth_,
        address wethOracle_
    ) public ERC20Dealer(treasury_, dai_, gasToken_, yDai_, weth_, wethOracle_) {
        //
    }

    /// @dev Takes weth from `from` address and posts it to the Treasury
    // from --- Weth ---> treasury
    function post(address from, uint256 weth) public override {
        // TODO: Consider a require on super.post()
        super.post(from, weth);                   // Grab weth and update posted
        _token.approve(address(_treasury), weth); // Treasury will take weth
        _treasury.post(address(this), weth);      // Post weth to Treasury
    }

    /// @dev Takes weth from Treasury and gives it to `to` address
    // us --- Token ---> to
    function withdraw(address to, uint256 weth) public override {
        _treasury.withdraw(address(this), weth);  // Take weth from Treasury
        super.withdraw(to, weth);                 // Check collateralization, send weth to user and update posted
        // TODO: Consider a require on super.withdraw()
    }

    /// @dev Deletes the debt from `from` and transfers `weth` to `to`.
    function liquidate(address from, address to, uint256 weth)
        public override onlyAuthorized("WethDealer: Not Authorized") nonReentrant
    {
        _treasury.withdraw(address(this), weth);  // Take weth from Treasury
        super.liquidate(from, to, weth);          // Update posted and debt, and send `weth` to `to`
    }
}