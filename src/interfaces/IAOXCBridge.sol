// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAOXCBridge
 * @notice Interface for cross-chain operations.
 */
interface IAOXCBridge {
    event CrossChainSent(uint16 dstChainId, address to, uint256 amount);
    event CrossChainReceived(uint16 srcChainId, address to, uint256 amount);

    function bridgeOut(uint16 _dstChainId, address _to, uint256 _amount) external payable;
    function bridgeIn(uint16 _srcChainId, address _to, uint256 _amount) external;

    function setChainSupport(uint16 _chainId, bool _status) external;
    function isChainSupported(uint16 _chainId) external view returns (bool);
}
