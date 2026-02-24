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

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { GovernorUpgradeable } from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {
    GovernorSettingsUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import {
    GovernorCountingSimpleUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import {
    GovernorVotesUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import {
    GovernorVotesQuorumFractionUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import {
    GovernorTimelockControlUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import {
    GovernorPreventLateQuorumUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorPreventLateQuorumUpgradeable.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {
    TimelockControllerUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import { AOXCConstants } from "./libraries/AOXCConstants.sol";
import { AOXCErrors } from "./libraries/AOXCErrors.sol";
import { AOXCStorage } from "./abstract/AOXCStorage.sol";

contract AOXCGovernor is
    Initializable,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorVotesUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    GovernorTimelockControlUpgradeable,
    GovernorPreventLateQuorumUpgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    AOXCStorage
{
    struct SubDaoPrivileges {
        bool isRegistered;
        bool canIssueAssets;
        uint256 vaultLimit;
        uint256 minReputationRequired;
        uint256 activeProposalLimit;
    }

    mapping(address => SubDaoPrivileges) public subDaoRegistry;
    uint256 public reputationThreshold;

    event SubDaoAuthorized(address indexed subDao, bool canIssueAssets, uint256 limit);
    event ReputationThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the governor with tokens and timelock.
     */
    function initialize(IVotes _token, TimelockControllerUpgradeable _timelock, address guardianAddr)
        external
        initializer
    {
        if (guardianAddr == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        __Governor_init("AOXC Sovereign DAO");
        __GovernorSettings_init(uint48(AOXCConstants.MIN_VOTING_DELAY), uint32(AOXCConstants.MAX_VOTING_PERIOD), 0);
        __GovernorCountingSimple_init();
        __GovernorVotes_init(_token);
        __GovernorVotesQuorumFraction_init(4);
        __GovernorTimelockControl_init(_timelock);
        __GovernorPreventLateQuorum_init(uint48(AOXCConstants.MIN_VOTING_DELAY));
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, guardianAddr);
        _grantRole(AOXCConstants.GUARDIAN_ROLE, guardianAddr);
        _grantRole(AOXCConstants.UPGRADER_ROLE, guardianAddr);

        reputationThreshold = 1000;
    }

    /*//////////////////////////////////////////////////////////////
                        CLOCK VIRTUALS (SOLC 0.8.33)
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev FIX: Removed 'override' keyword to solve Error (7792).
     * Solc 0.8.33 sees this as a new function definition in current OZ versions.
     */
    function clockMode() public pure returns (string memory) {
        return "mode=timestamp";
    }

    /**
     * @dev Explicitly overriding Governor and Votes modules for block.timestamp.
     */
    function clock() public view override(GovernorUpgradeable, GovernorVotesUpgradeable) returns (uint48) {
        return uint48(block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                            DAO LOGIC
    //////////////////////////////////////////////////////////////*/

    function authorizeSubDao(
        address subDaoContract,
        bool canIssueAssets,
        uint256 limit,
        uint256 minRep,
        uint256 proposalLimit
    ) external onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        if (subDaoContract == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        subDaoRegistry[subDaoContract] = SubDaoPrivileges({
            isRegistered: true,
            canIssueAssets: canIssueAssets,
            vaultLimit: limit,
            minReputationRequired: minRep,
            activeProposalLimit: proposalLimit
        });

        MainStorage storage $ = _getMainStorage();
        $.dynamicAddresses[keccak256(abi.encodePacked("SUB_DAO", subDaoContract))] = subDaoContract;

        emit SubDaoAuthorized(subDaoContract, canIssueAssets, limit);
    }

    function setReputationThreshold(uint256 newThreshold) external onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        emit ReputationThresholdUpdated(reputationThreshold, newThreshold);
        reputationThreshold = newThreshold;
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(GovernorUpgradeable) returns (uint256) {
        // V2 Storage naming fix
        uint256 callerRep = _getNftStorage().reputationPoints[msg.sender];

        if (callerRep < reputationThreshold) {
            revert AOXCErrors.AOXC_ThresholdNotMet(callerRep, reputationThreshold);
        }

        return super.propose(targets, values, calldatas, description);
    }

    function guardianCancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external onlyRole(AOXCConstants.GUARDIAN_ROLE) {
        _cancel(targets, values, calldatas, descriptionHash);
    }

    /*//////////////////////////////////////////////////////////////
                        BOILERPLATE OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function votingDelay() public view override(GovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(GovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(GovernorUpgradeable, GovernorVotesQuorumFractionUpgradeable)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function proposalThreshold()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function proposalDeadline(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorPreventLateQuorumUpgradeable)
        returns (uint256)
    {
        return super.proposalDeadline(proposalId);
    }

    function _tallyUpdated(uint256 proposalId)
        internal
        override(GovernorUpgradeable, GovernorPreventLateQuorumUpgradeable)
    {
        super._tallyUpdated(proposalId);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(GovernorUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(address) internal override onlyRole(AOXCConstants.UPGRADER_ROLE) { }

    uint256[47] private _gap;
}
