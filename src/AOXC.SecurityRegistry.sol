// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/*//////////////////////////////////////////////////////////////
    ___   ____ _  ________   ______ ____  ____  ______
   /   | / __ \ |/ / ____/  / ____// __ \/ __ \/ ____/
  / /| |/ / / /   / /      / /    / / / / /_/ / __/
 / ___ / /_/ /   / /___   / /___ / /_/ / _, _/ /___
/_/  |_\____/_/|_\____/   \____/ \____/_/ |_/_____/

    Sovereign Protocol Infrastructure | Storage Schema
//////////////////////////////////////////////////////////////*/

/**
 * @title AOXC Sovereign Storage Schema
 * @author AOXCAN AI & Orcun
 * @custom:contact      aoxcdao@gmail.com
 * @custom:website      https://aoxc.github.io/
 * @custom:repository   https://github.com/aoxc/AOXC-Core
 * @custom:social       https://x.com/AOXCDAO
 * @notice Centralized storage layout using ERC-7201 Namespaced Storage.
 * @dev High-fidelity storage pointers for gas efficiency and upgrade safety.
 * This pattern prevents storage collisions during complex proxy upgrades.
 */
//////////////////////////////////////////////////////////////*/

import {
    AccessManagerUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { AOXCStorage } from "./abstract/AOXCStorage.sol";
import { AOXCConstants } from "./libraries/AOXCConstants.sol";
import { AOXCErrors } from "./libraries/AOXCErrors.sol";

contract AOXCSecurityRegistry is Initializable, AccessManagerUpgradeable, UUPSUpgradeable, AOXCStorage {
    /// @notice Quarantine expiration timestamps per Sub-DAO address.
    mapping(address => uint256) public quarantineExpiries;

    /// @notice Manual emergency lock status per Sub-DAO address.
    mapping(address => bool) public subDaoEmergencyLocks;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event GlobalEmergencyLockToggled(address indexed caller, bool status);
    event QuarantineStarted(address indexed subDao, uint256 duration, address indexed triggeredBy);
    event SubDaoEmergencyLockToggled(address indexed subDao, address indexed caller, bool status);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the security registry with the primary administrator.
     * @param initialAdmin The initial administrator address for AccessManager.
     */
    function initialize(address initialAdmin) public override initializer {
        if (initialAdmin == address(0)) revert AOXCErrors.AOXC_InvalidAddress();
        __AccessManager_init(initialAdmin);
    }

    /*//////////////////////////////////////////////////////////////
                        1. FEDERATED CIRCUIT BREAKER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Global Kill-Switch: Instantly halts all critical protocol operations.
     */
    function triggerGlobalEmergency() external {
        _checkAoxcRole(AOXCConstants.GUARDIAN_ROLE, msg.sender);

        MainStorage storage $ = _getMainStorage();
        $.isGlobalLockActive = true;

        emit GlobalEmergencyLockToggled(msg.sender, true);
    }

    /**
     * @notice Global Recovery: Re-enables the entire protocol after a lock.
     */
    function releaseGlobalEmergency() external {
        _checkAoxcRole(AOXCConstants.GOVERNANCE_ROLE, msg.sender);

        MainStorage storage $ = _getMainStorage();
        $.isGlobalLockActive = false;

        emit GlobalEmergencyLockToggled(msg.sender, false);
    }

    /**
     * @notice Automated Quarantine: Temporarily locks a Sub-DAO for safety.
     * @dev SYNC FIX: Updated to _getNftStorage() to match V2 storage schema.
     */
    function triggerSubDaoQuarantine(address subDao, uint256 duration) external {
        if (subDao == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        // V2 Naming Sync
        uint256 callerRep = _getNftStorage().reputationPoints[msg.sender];

        if (callerRep < 500) {
            _checkAoxcRole(AOXCConstants.GUARDIAN_ROLE, msg.sender);
        }

        uint256 expiry = block.timestamp + duration;
        quarantineExpiries[subDao] = expiry;
        subDaoEmergencyLocks[subDao] = true;

        emit QuarantineStarted(subDao, duration, msg.sender);
    }

    /**
     * @notice Releases a Sub-DAO from its emergency lock.
     */
    function releaseSubDaoEmergency(address subDao) external {
        _checkAoxcRole(AOXCConstants.GOVERNANCE_ROLE, msg.sender);

        subDaoEmergencyLocks[subDao] = false;
        quarantineExpiries[subDao] = 0;

        emit SubDaoEmergencyLockToggled(subDao, msg.sender, false);
    }

    /*//////////////////////////////////////////////////////////////
                        2. SECURITY ANALYTICS (VIEW)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validation check for transaction permission across the ecosystem.
     */
    function isAllowed(address _caller, address subDaoTarget) external view returns (bool) {
        _caller; // Silence unused parameter

        if (_getMainStorage().isGlobalLockActive) return false;

        if (subDaoEmergencyLocks[subDaoTarget]) {
            return false;
        }

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal check for AOXC specific roles.
     */
    function _checkAoxcRole(bytes32 roleName, address account) internal view {
        uint64 roleId = uint64(uint256(roleName));
        (bool isMember,) = hasRole(roleId, account);
        if (!isMember) {
            revert AOXCErrors.AOXC_Unauthorized(roleName, account);
        }
    }

    /**
     * @dev Authorizes a UUPS upgrade.
     */
    function _authorizeUpgrade(
        address /* newImplementation */
    )
        internal
        override
    {
        _checkAoxcRole(AOXCConstants.UPGRADER_ROLE, msg.sender);
    }

    uint256[47] private _gap;
}
