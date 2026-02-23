// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAOXC
 * @notice Interface for the AOXC Governance Token.
 */
interface IAOXC {
    // Standard ERC20
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    // Mint & Burn (Role protected)
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;

    // Voting Logic (ERC20Votes)
    function getVotes(address account) external view returns (uint256);
    function getPastVotes(address account, uint256 timepoint) external view returns (uint256);
    function delegates(address account) external view returns (address);
    function delegate(address delegatee) external;

    // Compliance & Limits
    function isBlacklisted(address account) external view returns (bool);
    function isExcludedFromLimits(address account) external view returns (bool);
    function setExclusionFromLimits(address account, bool status) external;
}
