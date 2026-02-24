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
    TimelockControllerUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import { AOXCConstants } from "./libraries/AOXCConstants.sol";
import { AOXCErrors } from "./libraries/AOXCErrors.sol";

contract AOXCTimelock is TimelockControllerUpgradeable {
    /// @notice Custom minimum delays for specific Sub-DAO addresses.
    mapping(address => uint256) public subDaoMinDelays;

    event SubDaoDelayUpdated(address indexed subDao, uint256 newDelay);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the Timelock controller.
     * @dev FIX Error (9456): Added 'override' specifier to match the virtual function in base contract.
     */
    function initialize(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
        public
        override
        initializer
    {
        if (admin == address(0)) revert AOXCErrors.AOXC_InvalidAddress();
        __TimelockController_init(minDelay, proposers, executors, admin);
    }

    /**
     * @notice Allows the admin to set a custom minimum delay for specific Sub-DAOs.
     * @param subDao The address of the Sub-DAO contract.
     * @param newDelay The new delay duration in seconds.
     */
    function setSubDaoMinDelay(address subDao, uint256 newDelay) external {
        _checkRole(DEFAULT_ADMIN_ROLE, msg.sender);
        subDaoMinDelays[subDao] = newDelay;
        emit SubDaoDelayUpdated(subDao, newDelay);
    }

    /**
     * @notice Returns the minimum delay. Priority given to Sub-DAO custom delays.
     */
    function getMinDelay() public view override returns (uint256) {
        if (subDaoMinDelays[msg.sender] > 0) {
            return subDaoMinDelays[msg.sender];
        }
        return super.getMinDelay();
    }

    /**
     * @notice Guardian emergency cancellation of any pending operation.
     * @param id The operation identifier to cancel.
     */
    function guardianCancel(bytes32 id) external {
        _checkRole(AOXCConstants.GUARDIAN_ROLE, msg.sender);
        cancel(id);
    }

    /// @dev Storage gap for future upgrades.
    uint256[47] private _gap;
}
