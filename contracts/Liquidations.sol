pragma solidity ^0.6.2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ILiquidable.sol";
import "./interfaces/ITreasury.sol";


/// @dev The Liquidations contract for a Dealer allows to liquidate undercollateralized positions in a reverse Dutch auction.
contract Liquidations  {

    ILiquidable internal _dealer;
    ITreasury internal _treasury;
    IERC20 internal _dai;

    uint256 public fee;
    uint256 public auctionTime;

    mapping(address => uint256) public auctions;

    constructor (
        address dealer_,
        address treasury_,
        address dai_,
        uint256 fee_,
        uint256 auctionTime_
    ) public {
        _dealer = ILiquidable(dealer_);
        _treasury = ITreasury(treasury_);
        _dai = IERC20(dai_);
        fee = fee_;
        require(
            auctionTime_ > 0,
            "Liquidations: Auction time is zero"
        );
        _dai.approve(address(_treasury), uint256(-1)); // Treasury will not cheat on us
    }

    /// @dev Starts a liquidation process
    function start(address user) public {
        require(
            auctions[user] == 0,
            "Liquidations: User is already targeted"
        );
        require(
            _dealer.isUndercollateralized(user),
            "Liquidations: User is not undercollateralized"
        );
        // solium-disable-next-line security/no-block-members
        auctions[user] = now;
        _dealer.target(user, fee);       // Adds the liquidation fee to the user's debt.
        _treasury.pull(msg.sender, fee); // Pull dai from treasury to reward the starter
    }

    /// @dev Cancels a liquidation process
    function cancel(address user) public {
        require(
            auctions[user] > 0,
            "Liquidations: User is not targeted"
        );
        require(
            !_dealer.isUndercollateralized(user),
            "Liquidations: User is undercollateralized"
        );
        // solium-disable-next-line security/no-block-members
        delete auctions[user];
    }

    /// @dev Liquidates a position. The caller pays the debt of `from`, and `to` receives an amount of collateral.
    /// @param from User vault to liquidate
    /// @param to Account paying the debt and receiving the collateral
    function complete(address from, address to) public {
        require(
            auctions[from] > 0,
            "Liquidations: User is not targeted"
        );
        require(
            _dealer.isUndercollateralized(from),
            "Liquidations: User is not undercollateralized"
        );
        uint256 debt = _dealer.debtDai(from);
        delete auctions[from];

        require(
            _dai.transferFrom(msg.sender, address(this), debt), // The liquidator must have approved the dai payment
            "Liquidations: Dai transfer fail"
        );

        _treasury.push(address(this), debt);
        _dealer.liquidate(from, to, value(from));
    }

    /// @dev Return how much collateral would be obtained by liquidating a vault
    //
    //                                        elapsedTime
    // value = (2/3) posted + (1/3) posted * -------------
    //                                        auctionTime

    function value(address user) public view returns (uint256) {
        require(
            auctions[user] > 0,
            "Liquidations: User is not targeted"
        );
        return Math.min(
            _dealer.posted(user),
            (2 * _dealer.posted(user) / 3) + (_dealer.posted(user) * ((now - auctions[user]) / auctionTime) / 3)
        ); // TODO: Think about precision
    }
}