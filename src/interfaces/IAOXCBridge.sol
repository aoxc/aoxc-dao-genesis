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

interface IAOXCBridge {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event CrossChainSent(
        uint16 indexed dstChainId, address indexed from, address indexed to, uint256 amount, bytes32 messageId
    );

    event CrossChainReceived(uint16 indexed srcChainId, address indexed to, uint256 amount, bytes32 messageId);

    /*//////////////////////////////////////////////////////////////
                            CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiates a cross-chain transfer.
     * @param _dstChainId Destination chain identifier.
     * @param _to Recipient address on the destination chain.
     * @param _amount Amount of AOXC tokens to bridge.
     */
    function bridgeOut(uint16 _dstChainId, address _to, uint256 _amount) external payable;

    /**
     * @notice Finalizes a cross-chain transfer from another chain.
     * @param _srcChainId Source chain identifier.
     * @param _to Recipient address on this chain.
     * @param _amount Amount received.
     * @param _messageId Unique identifier for the cross-chain message.
     */
    function bridgeIn(uint16 _srcChainId, address _to, uint256 _amount, bytes32 _messageId) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Estimates the gas fee required for bridgeOut.
     */
    function quoteBridgeFee(uint16 _dstChainId, uint256 _amount) external view returns (uint256 nativeFee);

    /**
     * @notice Returns remaining daily limit for a specific chain.
     * @param _chainId The ID of the chain to check.
     * @param isOut True for outgoing (bridgeOut), False for incoming (bridgeIn).
     */
    function getRemainingLimit(uint16 _chainId, bool isOut) external view returns (uint256);

    /**
     * @notice Checks if a specific chain ID is whitelisted.
     */
    function isChainSupported(uint16 _chainId) external view returns (bool);

    /**
     * @notice Checks if a message has already been processed to prevent double-spending.
     */
    function processedMessages(bytes32 _messageId) external view returns (bool);
}
