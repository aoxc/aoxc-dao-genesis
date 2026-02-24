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

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";

/**
 * @title AOXC V2 (Upgrade Safe)
 * @notice Storage-compatible upgrade of AOXC V1
 */
contract AOXC is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    UUPSUpgradeable
{
    /*//////////////////////////////////////////////////////////////
                            V1 STORAGE (DO NOT MODIFY)
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant PAUSER_ROLE     = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE     = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE   = keccak256("UPGRADER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE"); 

    uint256 public constant INITIAL_SUPPLY         = 100_000_000_000 * 1e18;
    uint256 public constant YEAR_SECONDS           = 365 days;
    uint256 public constant HARD_CAP_INFLATION_BPS = 600;

    uint256 public yearlyMintLimit;
    uint256 public lastMintTimestamp;
    uint256 public mintedThisYear;
    uint256 public maxTransferAmount;
    uint256 public dailyTransferLimit;

    mapping(address => bool) private _blacklisted;
    mapping(address => string) public blacklistReason; 
    mapping(address => bool) public isExcludedFromLimits;
    mapping(address => uint256) public dailySpent;
    mapping(address => uint256) public lastTransferDay;

    /*//////////////////////////////////////////////////////////////
                            V2 NEW STORAGE
    //////////////////////////////////////////////////////////////*/

    bool public globalTransferLock;
    uint256 public dynamicTaxBps;
    address public treasury;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event GlobalTransferLockSet(bool status);
    event TreasuryUpdated(address treasury);
    event TaxUpdated(uint256 bps);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                            NEW INITIALIZER
    //////////////////////////////////////////////////////////////*/

    function initializeV2(address _treasury) external reinitializer(2) {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
        dynamicTaxBps = 0;
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    function _update(address from, address to, uint256 val)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable, ERC20VotesUpgradeable)
    {
        if (globalTransferLock) revert("Global lock active");

        if (from != address(0)) require(!_blacklisted[from], "BL Sender");
        if (to != address(0)) require(!_blacklisted[to], "BL Recipient");

        if (from != address(0) && to != address(0) && !isExcludedFromLimits[from]) {
            require(val <= maxTransferAmount, "MaxTX");

            uint256 day = block.timestamp / 1 days;
            if (lastTransferDay[from] != day) {
                dailySpent[from] = 0;
                lastTransferDay[from] = day;
            }

            require(dailySpent[from] + val <= dailyTransferLimit, "DailyLimit");
            dailySpent[from] += val;

            // Dynamic tax
            if (dynamicTaxBps > 0 && treasury != address(0)) {
                uint256 tax = (val * dynamicTaxBps) / 10000;
                super._update(from, treasury, tax);
                val -= tax;
            }
        }

        super._update(from, to, val);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN
    //////////////////////////////////////////////////////////////*/

    function setGlobalTransferLock(bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        globalTransferLock = status;
        emit GlobalTransferLockSet(status);
    }

    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "Zero addr");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    function setTax(uint256 bps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bps <= 1000, "Too high");
        dynamicTaxBps = bps;
        emit TaxUpdated(bps);
    }

    /*//////////////////////////////////////////////////////////////
                            UPGRADE AUTH
    //////////////////////////////////////////////////////////////*/

    function _authorizeUpgrade(address newImpl)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    function nonces(address owner)
        public
        view
        override(ERC20PermitUpgradeable, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    // v1 had 43 slots
    // we consumed 3 new slots
    uint256[40] private __gap;
}
