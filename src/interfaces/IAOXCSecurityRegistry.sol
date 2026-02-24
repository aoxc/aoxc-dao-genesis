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

import { IAccessManager } from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

interface IAOXCSecurityRegistry is IAccessManager {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event GlobalEmergencyLockToggled(address indexed caller, bool status);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if the protocol-wide circuit breaker is active.
     */
    function isGlobalEmergencyLocked() external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                            EMERGENCY LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Engages the emergency lock, pausing critical operations across the ecosystem.
     * @dev Should be restricted to high-privilege roles (e.g., GUARDIAN_ROLE).
     */
    function triggerEmergencyStop() external;

    /**
     * @notice Releases the emergency lock, resuming normal operations.
     * @dev Should typically require Governance or Timelock approval.
     */
    function releaseEmergencyStop() external;
}
