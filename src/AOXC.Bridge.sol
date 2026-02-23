// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AOXC Fortress Bridge
 * @author AOXC Protocol
 * @notice A high-security omnichain bridge manager featuring dual-directional rate limiting, 
 * guardian-led emergency stops, and replay attack prevention.
 * @dev Implements UUPS proxy pattern for upgradability and AccessControl for granular permissioning.
 */
contract AOXCBridge is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    // --- Roles ---
    /// @notice Role for emergency intervention (can pause but not unpause)
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    /// @notice Role for authorized off-chain relayers/operators
    bytes32 public constant BRIDGE_OPERATOR_ROLE = keccak256("BRIDGE_OPERATOR_ROLE");
    /// @notice Role authorized to trigger contract upgrades
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    /// @notice Role for strategic DAO parameters (limit changes, unpausing)
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    // --- State Variables ---
    IERC20 public aoxcToken;

    struct ChainConfig {
        bool isSupported;
        uint256 dailyLimitOut;    // Max allowed outflow per 24h
        uint256 dailyLimitIn;     // Max allowed inflow per 24h (Fortress security)
        uint256 currentSpentOut;
        uint256 currentSpentIn;
        uint256 lastResetTimestamp;
    }

    mapping(uint16 => ChainConfig) public chainConfigs;
    /// @notice Prevention against double-spending/replay attacks across chains
    mapping(bytes32 => bool) public processedMessages;

    // --- Errors ---
    error Bridge_ChainNotSupported();
    error Bridge_ZeroAmount();
    error Bridge_ExceedsDailyLimit();
    error Bridge_InvalidAddress();
    error Bridge_AlreadyProcessed();
    error Bridge_Unauthorized();

    // --- Events ---
    event SentToChain(uint16 indexed dstChainId, address indexed from, address indexed to, uint256 amount);
    event ReceivedFromChain(uint16 indexed srcChainId, address indexed to, uint256 amount, bytes32 messageId);
    event ChainConfigurationUpdated(uint16 indexed chainId, bool status, uint256 limitIn, uint256 limitOut);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the Fortress Bridge with essential security roles.
     * @param _governor The DAO Timelock/Governor address.
     * @param _guardian The Emergency Multisig/Security Committee address.
     * @param _aoxcToken The address of the AOXC token on this chain.
     */
    function initialize(address _governor, address _guardian, address _aoxcToken) public initializer {
        if (_governor == address(0) || _guardian == address(0) || _aoxcToken == address(0)) revert Bridge_InvalidAddress();

        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        aoxcToken = IERC20(_aoxcToken);

        _grantRole(DEFAULT_ADMIN_ROLE, _governor);
        _grantRole(GOVERNANCE_ROLE, _governor);
        _grantRole(UPGRADER_ROLE, _governor);
        _grantRole(GUARDIAN_ROLE, _guardian);
    }

    /*//////////////////////////////////////////////////////////////
                            BRIDGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiates a bridge transfer to a destination chain.
     * @dev Follows CEI pattern. Daily outflow limits are checked before locking funds.
     * @param _dstChainId Target chain identifier.
     * @param _to Recipient address on the destination chain.
     * @param _amount Amount of AOXC tokens to bridge.
     */
    function bridgeOut(uint16 _dstChainId, address _to, uint256 _amount) 
        external 
        payable 
        whenNotPaused 
        nonReentrant 
    {
        ChainConfig storage config = chainConfigs[_dstChainId];
        if (!config.isSupported) revert Bridge_ChainNotSupported();
        if (_amount == 0) revert Bridge_ZeroAmount();
        if (_to == address(0)) revert Bridge_InvalidAddress();

        // Effect: Update and validate rate limits
        _updateLimit(_dstChainId, _amount, true);

        // Interaction: Lock user tokens within the bridge contract
        aoxcToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit SentToChain(_dstChainId, msg.sender, _to, _amount);
    }

    /**
     * @notice Processes incoming transfers from supported source chains.
     * @dev Only callable by BRIDGE_OPERATOR_ROLE. Inflow limits prevent massive liquidity drains 
     * in case a connected source chain is compromised.
     * @param _srcChainId Originating chain identifier.
     * @param _to Recipient address on this chain.
     * @param _amount Amount of tokens to release.
     * @param _messageId Unique identifier for the cross-chain message to prevent replays.
     */
    function bridgeIn(uint16 _srcChainId, address _to, uint256 _amount, bytes32 _messageId)
        external
        onlyRole(BRIDGE_OPERATOR_ROLE)
        whenNotPaused
        nonReentrant
    {
        if (!chainConfigs[_srcChainId].isSupported) revert Bridge_ChainNotSupported();
        if (processedMessages[_messageId]) revert Bridge_AlreadyProcessed();
        if (_to == address(0)) revert Bridge_InvalidAddress();
        
        // Effect: Update and validate inflow rate limits
        _updateLimit(_srcChainId, _amount, false);

        processedMessages[_messageId] = true;
        
        // Interaction: Release tokens to the recipient
        aoxcToken.safeTransfer(_to, _amount);

        emit ReceivedFromChain(_srcChainId, _to, _amount, _messageId);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL SECURITY
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Logic for resetting and calculating 24-hour sliding window limits.
     */
    function _updateLimit(uint16 _chainId, uint256 _amount, bool isOut) internal {
        ChainConfig storage config = chainConfigs[_chainId];

        if (block.timestamp >= config.lastResetTimestamp + 1 days) {
            config.lastResetTimestamp = block.timestamp;
            config.currentSpentOut = 0;
            config.currentSpentIn = 0;
        }

        if (isOut) {
            if (config.currentSpentOut + _amount > config.dailyLimitOut) revert Bridge_ExceedsDailyLimit();
            config.currentSpentOut += _amount;
        } else {
            if (config.currentSpentIn + _amount > config.dailyLimitIn) revert Bridge_ExceedsDailyLimit();
            config.currentSpentIn += _amount;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN & GUARDIAN
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Configures chain support and dual-directional limits.
     * @onlyRole GOVERNANCE_ROLE
     */
    function configureChain(
        uint16 _chainId, 
        bool _status, 
        uint256 _limitIn, 
        uint256 _limitOut
    ) external onlyRole(GOVERNANCE_ROLE) {
        chainConfigs[_chainId].isSupported = _status;
        chainConfigs[_chainId].dailyLimitIn = _limitIn;
        chainConfigs[_chainId].dailyLimitOut = _limitOut;
        
        emit ChainConfigurationUpdated(_chainId, _status, _limitIn, _limitOut);
    }

    /**
     * @notice Immediate pause for emergency response.
     * @onlyRole GUARDIAN_ROLE
     */
    function emergencyPause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses the bridge. Only accessible by Governance.
     * @onlyRole GOVERNANCE_ROLE
     */
    function unpause() external onlyRole(GOVERNANCE_ROLE) {
        _unpause();
    }

    /**
     * @dev Internal requirement for UUPS upgrades.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    // Reserved storage slots for future versioning (Total 50)
    uint256[45] private __gap;
}
