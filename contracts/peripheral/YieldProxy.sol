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
    bytes32 private constant PROPOSED_ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.proposedAdmin")) - 1);
    bytes32 private constant VERSION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.version")) - 1);
    mapping(uint256 => address) public implementations; // Proxy version to implementation address
    mapping(address => uint256) public userChoices;     // User address to proxy version

    constructor() public {
        address sender = msg.sender;
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, sender)
        }
    }

    /// @dev Restricted to admin
    modifier onlyAdmin() {
        address admin;
        bytes32 slot = ADMIN_SLOT;
        assembly {
            admin := sload(slot)
        }
        require(msg.sender == admin, "YieldProxy: Restricted to admin");
        _;
    }

    /// @dev Store a `version` identifier in `VERSION_SLOT` as the latest version.
    function _setLatestVersion(uint256 version) internal {
		bytes32 slot = VERSION_SLOT;
		// solhint-disable-next-line no-inline-assembly
		assembly {
			sstore(slot, version)
		}
	}

    /// @dev Get the identifier of the latest version from `VERSION_SLOT`.
    function getLatestVersion() public view returns (uint256 version) {
		bytes32 slot = VERSION_SLOT;
		// solhint-disable-next-line no-inline-assembly
		assembly {
			version := sload(slot)
		}
	}

    /// @dev Get the address of the proxy implementation chosen by the user,
    /// or the address implementation of the latest version if none was chosen.
    function getImplementation() internal view returns (address) {
        address choice = implementations[userChoices[msg.sender]];
        return choice == address(0) ? implementations[getLatestVersion()] : choice;
    }

    /// @dev Choose a proxy `version` to use for the caller, using the sequential identifier.
    function chooseVersion(uint256 version) public {
        require(version <= getLatestVersion(), "Invalid version");
        userChoices[msg.sender] = version;
    }

    /// @dev Install a new proxy implementation, identified as the latest version.
    function upgradeTo(address implementation, bytes calldata data) public onlyAdmin {
        // change it
        uint256 version = getLatestVersion();
        implementations[version + 1] = implementation;
        _setLatestVersion(version + 1);

        (bool success,) = implementation.delegatecall(data);
        require(success);
    }

    /// @dev Propose an admin address change. Only available to admin.
    function proposeAdmin(address newAdmin) public onlyAdmin {
        bytes32 slot = PROPOSED_ADMIN_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, newAdmin)
        }
    }

    /// @dev Change the admin address. Only available to the proposed admin.
    function changeAdmin() public {
        bytes32 slot = PROPOSED_ADMIN_SLOT;
        address proposedAdmin;
        // solhint-disable-next-line no-inline-assembly
		assembly {
			proposedAdmin := sload(slot)
		}
        require(msg.sender == proposedAdmin, "YieldProxy: Restricted to proposed admin");

        slot = ADMIN_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, proposedAdmin)
        }
    }

    /// @dev Forward a call to the implementation address.
    fallback() external payable {
        address target = getImplementation();
        // solhint-disable-next-line no-inline-assembly
        assembly {
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
