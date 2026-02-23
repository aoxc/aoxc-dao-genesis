// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title AOXC Sovereign Token
 * @notice Enterprise-grade UUPS Token for X Layer. 
 * @dev Supports 100+ chains via Bridge-specific velocity exceptions and DAO-governed monetary policy.
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
    using SafeERC20 for IERC20;

    // --- ROLES ---
    bytes32 public constant PAUSER_ROLE     = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE     = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE   = keccak256("UPGRADER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant BRIDGE_ROLE     = keccak256("BRIDGE_ROLE"); // For 100-channel liquidity

    // --- MONETARY CONSTANTS ---
    uint256 public constant INITIAL_SUPPLY  = 100_000_000_000e18;
    uint256 public constant GLOBAL_CAP      = 300_000_000_000e18;
    uint256 public constant MAX_TAX_BPS     = 1_000; // Max 10%
    uint256 private constant BPS_DENOMINATOR = 10_000;
    uint256 public constant YEAR_SECONDS    = 365 days;

    // --- STATE VARIABLES (STRICT STORAGE ORDER) ---
    uint256 public yearlyMintLimit;
    uint256 public mintedThisYear;
    uint256 public lastMintTimestamp;
    uint256 public maxTransferAmount;
    uint256 public dailyTransferLimit;

    uint256 public taxBasisPoints;
    bool public taxEnabled;
    address public treasury;

    mapping(address => bool) private _blacklisted;
    mapping(address => string) public blacklistReason;
    mapping(address => bool) public isExcludedFromLimits;
    mapping(address => uint256) public dailySpent;
    mapping(address => uint256) public lastTransferDay;
    mapping(address => uint256) public userLockUntil;

    // --- ERRORS ---
    error AOXC_ZeroAddress();
    error AOXC_GlobalCapExceeded();
    error AOXC_InflationLimitReached();
    error AOXC_TaxTooHigh();
    error AOXC_MaxTxExceeded();
    error AOXC_DailyLimitExceeded();
    error AOXC_AccountBlacklisted(address account);
    error AOXC_AccountLocked(address account, uint256 until);
    error AOXC_Unauthorized();

    // --- EVENTS ---
    event Blacklisted(address indexed account, string reason);
    event Unblacklisted(address indexed account);
    event UserLocked(address indexed account, uint256 until);
    event TaxConfigured(uint256 bps, bool enabled, address treasury);
    event VelocityUpdated(uint256 maxTx, uint256 dailyLimit);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address governor) external initializer {
        if (governor == address(0)) revert AOXC_ZeroAddress();

        __ERC20_init("AOXC Token", "AOXC");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init("AOXC Token");
        __ERC20Votes_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(GOVERNANCE_ROLE, governor);
        _grantRole(MINTER_ROLE, governor);
        _grantRole(PAUSER_ROLE, governor);
        _grantRole(UPGRADER_ROLE, governor);
        _grantRole(COMPLIANCE_ROLE, governor);

        // Audit-Grade Default Limits
        maxTransferAmount = 1_000_000_000e18; 
        dailyTransferLimit = 2_000_000_000e18;
        yearlyMintLimit = (INITIAL_SUPPLY * 600) / BPS_DENOMINATOR; // 6%

        lastMintTimestamp = block.timestamp;
        isExcludedFromLimits[governor] = true;
        isExcludedFromLimits[address(this)] = true;
        treasury = governor;

        _mint(governor, INITIAL_SUPPLY);
    }

    /*//////////////////////////////////////////////////////////////
                            MONETARY POLICY
    //////////////////////////////////////////////////////////////*/

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        if (to == address(0)) revert AOXC_ZeroAddress();
        if (_blacklisted[to]) revert AOXC_AccountBlacklisted(to);
        if (totalSupply() + amount > GLOBAL_CAP) revert AOXC_GlobalCapExceeded();

        // Compounding Inflation Logic
        if (block.timestamp >= lastMintTimestamp + YEAR_SECONDS) {
            mintedThisYear = 0;
            lastMintTimestamp = block.timestamp;
            yearlyMintLimit = (totalSupply() * 600) / BPS_DENOMINATOR;
        }

        if (mintedThisYear + amount > yearlyMintLimit) revert AOXC_InflationLimitReached();

        mintedThisYear += amount;
        _mint(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            COMPLIANCE LOGIC
    //////////////////////////////////////////////////////////////*/

    function addToBlacklist(address user, string calldata reason) external onlyRole(COMPLIANCE_ROLE) {
        if (hasRole(DEFAULT_ADMIN_ROLE, user)) revert AOXC_Unauthorized();
        _blacklisted[user] = true;
        blacklistReason[user] = reason;
        emit Blacklisted(user, reason);
    }

    function lockUserFunds(address user, uint256 duration) external onlyRole(COMPLIANCE_ROLE) {
        userLockUntil[user] = block.timestamp + duration;
        emit UserLocked(user, userLockUntil[user]);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL ENGINE
    //////////////////////////////////////////////////////////////*/

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable, ERC20VotesUpgradeable)
    {
        // 1. Compliance Layer
        if (from != address(0)) {
            if (_blacklisted[from]) revert AOXC_AccountBlacklisted(from);
            if (block.timestamp < userLockUntil[from]) revert AOXC_AccountLocked(from, userLockUntil[from]);
        }
        if (to != address(0) && _blacklisted[to]) revert AOXC_AccountBlacklisted(to);

        uint256 finalAmount = value;

        // 2. Velocity & Tax Layer (Skip for Authorized Bridges & Admin)
        if (from != address(0) && to != address(0) && !isExcludedFromLimits[from] && !hasRole(BRIDGE_ROLE, from)) {
            // Velocity Checks
            if (value > maxTransferAmount) revert AOXC_MaxTxExceeded();
            
            uint256 day = block.timestamp / 1 days;
            if (lastTransferDay[from] != day) {
                lastTransferDay[from] = day;
                dailySpent[from] = 0;
            }
            if (dailySpent[from] + value > dailyTransferLimit) revert AOXC_DailyLimitExceeded();
            dailySpent[from] += value;

            // Tax logic
            if (taxEnabled && taxBasisPoints > 0) {
                uint256 tax = (value * taxBasisPoints) / BPS_DENOMINATOR;
                if (tax > 0) {
                    finalAmount = value - tax;
                    super._update(from, treasury, tax);
                }
            }
        }

        super._update(from, to, finalAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function configureTax(uint256 bps, bool enabled, address _treasury) external onlyRole(GOVERNANCE_ROLE) {
        if (bps > MAX_TAX_BPS) revert AOXC_TaxTooHigh();
        taxBasisPoints = bps;
        taxEnabled = enabled;
        treasury = _treasury;
        emit TaxConfigured(bps, enabled, _treasury);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    // Governance Clock
    function clock() public view override returns (uint48) { return uint48(block.timestamp); }
    function CLOCK_MODE() public pure override returns (string memory) { return "mode=timestamp"; }

    function nonces(address owner) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
        return super.nonces(owner);
    }

    uint256[40] private _gap; // Storage gap for future expansion
}
