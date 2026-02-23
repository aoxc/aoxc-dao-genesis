// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

// Senin tree yapına göre güncellenmiş yollar
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyMockUpgradeable.sol"; // ReentrancyGuard ağacında mock/utils arasında olabilir, standart yolu budur
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AOXC Secure Treasury
 * @notice 6-year base lock + Recurring 1-year windows + 6% Yearly Withdrawal Limit.
 */
contract AOXCTreasury is Initializable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint256 public constant INITIAL_LOCK_DURATION = 6 * 365 days;
    uint256 public constant RECURRING_WINDOW = 365 days;
    uint256 public constant MAX_WITHDRAWAL_BPS = 600; // %6
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /*//////////////////////////////////////////////////////////////
                                   STATE
    //////////////////////////////////////////////////////////////*/
    uint256 public initialUnlockTimestamp;
    uint256 public currentWindowEnd;
    bool public emergencyMode;

    mapping(address => uint256) public periodWithdrawn;
    mapping(address => uint256) public periodStartBalance;

    error Treasury_ZeroAddress();
    error Treasury_VaultLocked(uint256 current, uint256 unlockTime);
    error Treasury_WindowClosed();
    error Treasury_ExceedsSixPercentLimit();
    error Treasury_TransferFailed();

    event WindowOpened(uint256 windowEnd);
    event EmergencyModeToggled(bool status);
    event FundsWithdrawn(address indexed token, address indexed to, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _governor) external initializer {
        if (_governor == address(0)) revert Treasury_ZeroAddress();

        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _governor);
        _grantRole(GOVERNANCE_ROLE, _governor);
        _grantRole(EMERGENCY_ROLE, _governor);
        _grantRole(UPGRADER_ROLE, _governor);

        initialUnlockTimestamp = block.timestamp + INITIAL_LOCK_DURATION;
    }

    /*//////////////////////////////////////////////////////////////
                             LOCK & LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function openSpendingWindow() external onlyRole(GOVERNANCE_ROLE) {
        if (block.timestamp < initialUnlockTimestamp) {
            revert Treasury_VaultLocked(block.timestamp, initialUnlockTimestamp);
        }
        currentWindowEnd = block.timestamp + RECURRING_WINDOW;
        periodStartBalance[address(0)] = address(this).balance;
        emit WindowOpened(currentWindowEnd);
    }

    function _verifyLimit(address token, uint256 amount) internal {
        if (emergencyMode) return;

        if (periodStartBalance[token] == 0) {
            periodStartBalance[token] =
                (token == address(0)) ? address(this).balance : IERC20(token).balanceOf(address(this));
        }

        uint256 maxAllowed = (periodStartBalance[token] * MAX_WITHDRAWAL_BPS) / BPS_DENOMINATOR;
        if (periodWithdrawn[token] + amount > maxAllowed) {
            revert Treasury_ExceedsSixPercentLimit();
        }
        periodWithdrawn[token] += amount;
    }

    modifier checkLock(address token, uint256 amount) {
        if (!emergencyMode) {
            if (block.timestamp < initialUnlockTimestamp) {
                revert Treasury_VaultLocked(block.timestamp, initialUnlockTimestamp);
            }
            if (block.timestamp > currentWindowEnd) revert Treasury_WindowClosed();
            _verifyLimit(token, amount);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             ASSET MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function withdrawERC20(address token, address to, uint256 amount)
        external
        onlyRole(GOVERNANCE_ROLE)
        checkLock(token, amount)
        whenNotPaused
    {
        if (to == address(0)) revert Treasury_ZeroAddress();
        IERC20(token).safeTransfer(to, amount);
        emit FundsWithdrawn(token, to, amount);
    }

    function withdrawETH(address payable to, uint256 amount)
        external
        onlyRole(GOVERNANCE_ROLE)
        checkLock(address(0), amount)
        whenNotPaused
    {
        if (to == address(0)) revert Treasury_ZeroAddress();
        (bool success,) = to.call{value: amount}("");
        if (!success) revert Treasury_TransferFailed();
        emit FundsWithdrawn(address(0), to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                             ADMIN & UPGRADE
    //////////////////////////////////////////////////////////////*/

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function toggleEmergencyMode(bool status) external onlyRole(EMERGENCY_ROLE) {
        emergencyMode = status;
        emit EmergencyModeToggled(status);
    }

    function resetPeriod() external onlyRole(GOVERNANCE_ROLE) {
        // İhtiyaca göre periodWithdrawn mapping'i temizlenebilir.
    }

    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(GOVERNANCE_ROLE) {
        _unpause();
    }

    receive() external payable {}

    // Storage gap for future upgrades
    uint256[43] private __gap;
}
