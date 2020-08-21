// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

import "../interfaces/IChai.sol";
import "../interfaces/IController.sol";
import "../interfaces/IWeth.sol";


/// @dev EthProxy allows users to post and withdraw Eth to the Controller, which will be converted to and from Weth in the process.
contract EthProxy {

    bytes32 public constant WETH = "ETH-A";
    bytes32 public constant CHAI = "CHAI";

    IWeth public weth;
    IChai public chai;
    address public treasury;
    IController public controller;

    constructor (
        address payable weth_,
        address chai_,
        address controller_
    ) public {
        weth = IWeth(weth_);
        chai = IChai(chai_);
        controller = IController(controller_);
        treasury = address(controller.treasury());
        weth.approve(treasury, uint(-1));
    }

    /// @dev The WETH9 contract will send ether to EthProxy on `weth.withdraw` using this function.
    receive() external payable { }

    /// @dev Users use `post` in EthProxy to post ETH to the Controller, which will be converted to Weth here.
    /// @param to Yield Vault to deposit collateral in.
    /// @param amount Amount of collateral to move.
    function post(address to, uint256 amount)
        public payable {
        weth.deposit{ value: amount }();
        controller.post(WETH, address(this), to, amount);
    }

    /// @dev Post Chai to the Controller using signatures instead of approvals
    /// @param to Yield Vault to deposit collateral in.
    /// @param chaiIn Amount of chai to post.
    /// @param deadline Latest block timestamp for which the signature is valid
    /// @param delegateSig ABI-encoded (uint8 v, bytes32 r, bytes32 s) `addDelegateBySignature` signature
    /// @param permitSig ABI-encoded (uint8 v, bytes32 r, bytes32 s) `permit` signature
    /// The permit must be for (owner, treasury.address, chaiIn)
    /// If an empty bytes variable is passed as a signature its related call won't be attempted
    /// If both signatures are provided, the deadline for both must be the same
    function postChaiBySignature(
        address to, uint256 chaiIn, 
        uint nonce, uint deadline, bytes calldata delegateSig, bytes calldata permitSig
    )
        public {
        if (delegateSig.length != 0) {
            (uint8 v, bytes32 r, bytes32 s) = abi.decode(delegateSig, (uint8, bytes32, bytes32));
            controller.addDelegateBySignature(msg.sender, address(this), deadline, v, r, s);
        }
        if (permitSig.length != 0) {
            (uint8 v, bytes32 r, bytes32 s) = abi.decode(permitSig, (uint8, bytes32, bytes32));
            chai.permit(msg.sender, treasury, nonce, deadline, true, v, r, s);
        }
        controller.post(CHAI, msg.sender, to, chaiIn);
    }


    /// @dev Users wishing to withdraw their Weth as ETH from the Controller should use this function.
    /// Users must have called `controller.addDelegate(ethProxy.address)` to authorize EthProxy to act in their behalf.
    /// @param to Wallet to send Eth to.
    /// @param amount Amount of weth to move.
    function withdraw(address payable to, uint256 amount)
        public {
        controller.withdraw(WETH, msg.sender, address(this), amount);
        weth.withdraw(amount);
        to.transfer(amount);
    }

    /// @dev Users wishing to withdraw their Weth as ETH from the Controller should use this function.
    /// Users must supply an encoded signature for Controller add EthProxy as a delegate.
    /// @param to Wallet to send Eth to.
    /// @param amount Amount of weth to move.
    /// @param deadline Latest block timestamp for which the signature is valid
    /// @param v Signature parameter
    /// @param r Signature parameter
    /// @param s Signature parameter
    function withdrawBySignature(address payable to, uint256 amount, uint deadline, uint8 v, bytes32 r, bytes32 s)
        public {
        controller.addDelegateBySignature(msg.sender, address(this), deadline, v, r, s);
        withdraw(to, amount);
    }
}