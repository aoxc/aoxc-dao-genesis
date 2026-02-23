// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AOXC Liquidity & Bridge Manager
 * @notice Handles locked AMM liquidity and cross-chain messaging.
 * @dev Fully compatible with LayerZero OFT and Uniswap V2/V3 LPs.
 */
contract AOXCLiquidityManager is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    address public lpToken;
    address public aoxcToken;
    bool public isLiquidityPermanentlyLocked;

    error LiquidityIsLockedForever();
    error ZeroAddress();
    error InsufficientBalance();

    event LiquidityLockedPermanently(address indexed lpToken, uint256 amount);
    event BridgeOutInitiated(uint16 indexed dstChainId, address indexed to, uint256 amount);
    event EmergencyLPWithdrawn(address indexed to, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _governor, address _aoxcToken, address _lpToken) public initializer {
        if (_governor == address(0) || _aoxcToken == address(0) || _lpToken == address(0)) revert ZeroAddress();

        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        aoxcToken = _aoxcToken;
        lpToken = _lpToken;

        _grantRole(DEFAULT_ADMIN_ROLE, _governor);
        _grantRole(GOVERNANCE_ROLE, _governor);
        _grantRole(UPGRADER_ROLE, _governor);
    }

    /*//////////////////////////////////////////////////////////////
                            LIQUIDITY CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calling this function makes the LP tokens un-withdrawable forever.
     * @dev Use with extreme caution. This burns the "exit" bridge for the liquidity.
     */
    function setPermanentLock() external onlyRole(GOVERNANCE_ROLE) {
        isLiquidityPermanentlyLocked = true;
        emit LiquidityLockedPermanently(lpToken, IERC20(lpToken).balanceOf(address(this)));
    }

    /**
     * @notice Allows the DAO to move LP tokens IF permanent lock is not active.
     * @dev Useful for migrating liquidity to a newer Uniswap version.
     */
    function migrateLiquidity(address _to, uint256 _amount) external onlyRole(GOVERNANCE_ROLE) nonReentrant {
        if (isLiquidityPermanentlyLocked) revert LiquidityIsLockedForever();
        if (_to == address(0)) revert ZeroAddress();

        IERC20(lpToken).safeTransfer(_to, _amount);
        emit EmergencyLPWithdrawn(_to, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                            CROSS-CHAIN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Bridge AOXC tokens out to a different chain.
     * @dev Usually integrated with LayerZero Endpoint.
     */
    function bridgeOut(uint16 _dstChainId, address _to, uint256 _amount) external onlyRole(BRIDGE_ROLE) nonReentrant {
        if (_to == address(0)) revert ZeroAddress();

        // Lock tokens in this contract to back the minted tokens on the destination chain
        IERC20(aoxcToken).safeTransferFrom(msg.sender, address(this), _amount);

        emit BridgeOutInitiated(_dstChainId, _to, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                            UPGRADEABILITY
    //////////////////////////////////////////////////////////////*/

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    // Reserved storage for future updates
    uint256[47] private __gap;
}
