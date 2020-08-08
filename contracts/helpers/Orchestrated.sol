// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";


/**
 * @dev Orchestrated allows to define static access control between multiple contracts.
 * This contract would be used as a parent contract of any contract that needs to restrict access to some methods,
 * which would be marked with the `onlyOrchestrated modifier.
 * During deployment, the contract deployer can register any contracts that have privileged access by calling `orchestrate`.
 * Once deployment is completed, `deployer` should call `renounceRole(DEFAULT_ADMIN_ROLE, deployer)` to avoid any more contracts ever gaining privileged access.
 */

contract Orchestrated is AccessControl {
    using Address for address;

    bytes32 public constant YIELD_CONTRACT = "YIELD_CONTRACT";

    /// @dev The constructor gives the deployer address the root role that can call `orchestrate`
    constructor () public {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /// @dev Restrict usage to deployer
    /// @param err Error message to return on failure
    modifier onlyDeployer(string memory err) {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), err);
        _;
    }

    /// @dev Restrict usage to registered contracts
    /// @param err Error message to return on failure
    modifier onlyOrchestrated(string memory err) {
        require(hasRole(YIELD_CONTRACT, _msgSender()), err);
        _;
    }

    /// @dev Register a contract for privileged access
    /// @param toOrchestrate The address of the contract receiving privileged access
    function orchestrate(address toOrchestrate) public onlyDeployer("Orchestrated: Restricted to deployer") {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Orchestrated: Restricted to deployer");
        require(toOrchestrate.isContract(), "Orchestrated: Only contracts can be orchestrated");
        grantRole(YIELD_CONTRACT, toOrchestrate);
    }
}
