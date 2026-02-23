// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAOXCTreasury
 * @notice Interface for the AOXC DAO Treasury.
 */
interface IAOXCTreasury {
    event FundsDisbursed(address indexed receiver, uint256 amount, string reason);
    event LimitUpdated(uint256 newLimitBps);

    function deposit() external payable;
    function withdraw(address token, address to, uint256 amount) external;
    function requestEmergencyFunds(uint256 amount) external;

    // View functions for Dashboard
    function getAvailableLimit() external view returns (uint256);
    function totalFundsManaged(address token) external view returns (uint256);
}
