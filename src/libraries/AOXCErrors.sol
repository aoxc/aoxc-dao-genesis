// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/*//////////////////////////////////////////////////////////////
    ___   ____ _  ________   ______ ____  ____  ______
   /   | / __ \ |/ / ____/  / ____// __ \/ __ \/ ____/
  / /| |/ / / /   / /      / /    / / / / /_/ / __/
 / ___ / /_/ /   / /___   / /___ / /_/ / _, _/ /___
/_/  |_\____/_/|_\____/   \____/ \____/_/ |_/_____/

    Sovereign Protocol Infrastructure | Core Library
//////////////////////////////////////////////////////////////*/

/**
 * @title AOXC Global Error Library
 * @author AOXC Protocol Team
 * @notice Centralized gateway for protocol-wide parameterized custom errors.
 * @dev Designed for AOXC-Core to minimize gas consumption while maintaining
 * high-fidelity diagnostic data for frontend and off-chain integrators.
 */
library AOXCErrors {
    /*//////////////////////////////////////////////////////////////
                        IDENTITY & ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when an account lacks the required administrative role.
     * @param role The bytes32 identifier of the required role.
     * @param account The address that attempted the unauthorized action.
     */
    error AOXC_Unauthorized(bytes32 role, address account);

    /// @notice Thrown when a zero-address (0x0) is passed to a sensitive function.
    error AOXC_InvalidAddress();

    /// @notice Thrown when attempting to re-initialize an already active contract state.
    error AOXC_AlreadyInitialized();

    /*//////////////////////////////////////////////////////////////
                        MONETARY & LIQUIDITY LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when an operation is triggered with an input amount of zero.
    error AOXC_ZeroAmount();

    /**
     * @notice Thrown when a balance check fails during a withdrawal or transfer.
     * @param available The current balance of the account.
     * @param required The amount required to complete the operation.
     */
    error AOXC_InsufficientBalance(uint256 available, uint256 required);

    /**
     * @notice Thrown when a transfer exceeds the approved ERC20 allowance.
     * @param available The current allowance granted by the owner.
     * @param required The amount attempted to be spent.
     */
    error AOXC_ExceedsAllowance(uint256 available, uint256 required);

    /// @notice Thrown when a sanctioned or blacklisted address attempts an interaction.
    error AOXC_Blacklisted(address account);

    /// @notice Thrown when a Basis Point (BPS) value exceeds the 10,000 (100%) limit.
    error AOXC_InvalidBPS(uint256 provided, uint256 maxAllowed);

    /*//////////////////////////////////////////////////////////////
                        VELOCITY & INFLATION LIMITS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when a single transfer exceeds the maximum allowed velocity cap.
     * @param amount The attempted transfer amount.
     * @param maxLimit The current per-transaction limit.
     */
    error AOXC_VelocityLimitExceeded(uint256 amount, uint256 maxLimit);

    /**
     * @notice Thrown when a user hits their cumulative daily transfer quota.
     * @param user The address attempting the transfer.
     * @param spent The amount already spent today.
     * @param limit The maximum daily allowance.
     */
    error AOXC_DailyLimitReached(address user, uint256 spent, uint256 limit);

    /**
     * @notice Thrown when minting would exceed the global or annual inflation caps.
     * @param requested The amount attempted to mint.
     * @param available The remaining headroom in the cap.
     */
    error AOXC_InflationCapReached(uint256 requested, uint256 available);

    /*//////////////////////////////////////////////////////////////
                        STAKING & LOCK MECHANISMS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the staking engine is disabled or undergoing maintenance.
    error AOXC_StakeNotActive();

    /// @notice Thrown when a non-existent or unsupported lock-up duration is selected.
    error AOXC_InvalidLockTier(uint256 providedTier);

    /// @notice Thrown when an out-of-bounds stake index is queried.
    error AOXC_InvalidStakeIndex(uint256 index);

    /**
     * @notice Thrown when a withdrawal is attempted before the maturity date.
     * @param currentTime The current block timestamp.
     * @param unlockTime The scheduled release timestamp.
     */
    error AOXC_StakeStillLocked(uint256 currentTime, uint256 unlockTime);

    /*//////////////////////////////////////////////////////////////
                        BRIDGE & MULTI-CHAIN
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when a cross-chain operation is attempted to an unverified chain.
     * @param chainId The ID of the unsupported destination chain.
     */
    error AOXC_ChainNotSupported(uint256 chainId);

    /**
     * @notice Thrown when the bridge limit for a specific period is exceeded.
     * @param amount The amount attempted to bridge.
     * @param limit The current bridge capacity.
     */
    error AOXC_BridgeLimitExceeded(uint256 amount, uint256 limit);

    /**
     * @notice Thrown when a bridge transaction is already processed.
     * @param txHash The unique hash of the cross-chain transaction.
     */
    error AOXC_BridgeTxAlreadyProcessed(bytes32 txHash);

    /**
     * @notice Thrown when Sub-DAO or Bridge volume exceeds defined thresholds.
     * @param provided The attempted volume.
     * @param threshold The allowed threshold limit.
     */
    error AOXC_ThresholdNotMet(uint256 provided, uint256 threshold);

    /*//////////////////////////////////////////////////////////////
                        DAO & DYNAMIC GOVERNANCE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice THE SOVEREIGN GATE: Reverts based on DAO-enacted dynamic rules.
     * @param ruleId Unique identifier for the violated governance rule.
     * @param actor The address that triggered the rule violation.
     * @param details Encoded metadata explaining the context of the breach.
     */
    error AOXC_GovernanceRuleViolation(uint256 ruleId, address actor, bytes details);

    /**
     * @notice Flexible revert mechanism for unforeseen protocol edge cases.
     * @param reason A descriptive string defining the revert cause.
     */
    error AOXC_CustomRevert(string reason);
}
