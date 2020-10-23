// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

import "./ProxyStorage.sol";
import "./SafeCast.sol";

import "../interfaces/IDai.sol";
import "../interfaces/IPool.sol";
import "../interfaces/ITreasury.sol";
import "../interfaces/IController.sol";
import "../helpers/DecimalMath.sol";

// Contains all the authorization logic
contract YieldAuth {
    /// @dev Unpack r, s and v from a `bytes` signature
    function unpack(bytes memory signature) private pure returns (bytes32 r, bytes32 s, uint8 v) {
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
    }

    /// @dev Performs the initial onboarding of the user. It `permit`'s DAI to be used by the proxy, and adds the proxy as a delegate in the controller
    function onboard(IDai dai, IController controller, address from, bytes memory daiSignature, bytes memory controllerSig) external {
        bytes32 r;
        bytes32 s;
        uint8 v;

        (r, s, v) = unpack(daiSignature);
        dai.permit(from, address(this), dai.nonces(from), uint(-1), true, v, r, s);

        (r, s, v) = unpack(controllerSig);
        controller.addDelegateBySignature(from, address(this), uint(-1), v, r, s);
    }

    /// @dev Given a pool and 3 signatures, it `permit`'s dai and fyDai for that pool and adds it as a delegate
    function authorizePool(IPool pool, IDai dai, address from, bytes memory daiSig, bytes memory fyDaiSig, bytes memory poolSig) public {
        bytes32 r;
        bytes32 s;
        uint8 v;

        (r, s, v) = unpack(daiSig);
        dai.permit(from, address(pool), dai.nonces(from), uint(-1), true, v, r, s);

        (r, s, v) = unpack(fyDaiSig);
        pool.fyDai().permit(from, address(this), uint(-1), uint(-1), v, r, s);

        (r, s, v) = unpack(poolSig);
        pool.addDelegateBySignature(from, address(this), uint(-1), v, r, s);
    }

    /// @dev The WETH9 contract will send ether to YieldProxy on `weth.withdraw` using this function.
    receive() external payable { }
}

// proxy contract with no storage
contract YieldProxy is YieldAuth {
    // EIP1967 storage slots to avoid conflicts
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
    bytes32 private constant _VERSION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.version")) - 1);
    mapping(uint256 => address) public implementations;
    mapping(address => uint256) public userChoices;

    constructor() public {
        address sender = msg.sender;
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, sender)
        }
    }

    function _setVersion(uint256 version) internal {
		bytes32 slot = _VERSION_SLOT;
		// solhint-disable-next-line no-inline-assembly
		assembly {
			sstore(slot, version)
		}
	}

    function getVersion() public view returns (uint256 version) {
		bytes32 slot = _VERSION_SLOT;
		// solhint-disable-next-line no-inline-assembly
		assembly {
			version := sload(slot)
		}
	}

    function getImplementation() internal view returns (address) {
        address choice = implementations[userChoices[msg.sender]];
        return choice == address(0) ? implementations[getVersion()] : choice;
    }

    function chooseVersion(uint256 version) public {
        require(version <= getVersion(), "Invalid version");
        userChoices[msg.sender] = version;
    }

    function upgradeTo(address implementation, bytes calldata data) public {
        // load the admin
        address admin;
        bytes32 slot = ADMIN_SLOT;
        assembly {
            admin := sload(slot)
        }

        // check it
        require(msg.sender == admin);

        // change it
        uint256 version = getVersion();
        implementations[version + 1] = implementation;
        _setVersion(version + 1);

        (bool success,) = implementation.delegatecall(data);
        require(success);
    }

    function changeAdmin(address newAdmin) public {
        // load the admin
        address admin;
        bytes32 slot = ADMIN_SLOT;
        assembly {
            admin := sload(slot)
        }

        // check it
        require(msg.sender == admin);

        // change it
        assembly {
            sstore(slot, newAdmin)
        }
    }

    fallback() external payable {
        address target = getImplementation();
        assembly {
            //let target := sload(slot)
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), target, 0x0, calldatasize(), 0x0, 0)
            let retSize := returndatasize()
            returndatacopy(0x0, 0x0, retSize)
            switch result
            case 0 {revert(0, retSize)}
            default {return (0, retSize)}
        }
    }
}
