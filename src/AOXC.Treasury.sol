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

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AOXCConstants } from "./libraries/AOXCConstants.sol";
import { AOXCErrors } from "./libraries/AOXCErrors.sol";

interface IAOXCGuard {
    function validate(uint256 cellId, address token, uint256 amount) external view returns (bool);
}

contract AOXCSovereignFortress is Initializable, AccessControlUpgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct TreasuryCell {
        uint256 dailyLimit;
        uint256 currentVolume;
        uint256 lastReset;
        bool isAmputated;
        address manager;
    }

    mapping(uint256 => TreasuryCell) public cells;
    uint256 public cellCount;
    bool public globalNeuralLock;
    address[] public defenseWalls;

    event WallAdded(address indexed wall);
    event NeuralLockActivated(string reason);
    event CellAmputated(uint256 indexed cellId, string reason);
    event FundsReleased(uint256 indexed cellId, address to, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address governor) external initializer {
        if (governor == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(AOXCConstants.GOVERNANCE_ROLE, governor);
        _grantRole(AOXCConstants.GUARDIAN_ROLE, governor);
    }

    /*//////////////////////////////////////////////////////////////
                        MODULAR DEFENSE LOGIC
    //////////////////////////////////////////////////////////////*/

    function addDefenseWall(address wall) external onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        if (wall == address(0)) revert AOXCErrors.AOXC_InvalidAddress();
        defenseWalls.push(wall);
        emit WallAdded(wall);
    }

    /**
     * @dev Internal validation logic for security walls.
     */
    function _checkAllWalls(uint256 cellId, address token, uint256 amount) internal view {
        uint256 len = defenseWalls.length;
        for (uint256 i = 0; i < len;) {
            if (!IAOXCGuard(defenseWalls[i]).validate(cellId, token, amount)) {
                revert AOXCErrors.AOXC_CustomRevert("WALL_BLOCK: REJECTED");
            }
            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            CELL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function createCell(uint256 limit, address manager) external onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        if (manager == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        cellCount++;
        cells[cellCount] = TreasuryCell({
            dailyLimit: limit, currentVolume: 0, lastReset: block.timestamp, isAmputated: false, manager: manager
        });
    }

    function withdraw(uint256 cellId, address token, uint256 amount, address to) external nonReentrant {
        if (globalNeuralLock) revert AOXCErrors.AOXC_CustomRevert("SYSTEM_SEALED");

        TreasuryCell storage cell = cells[cellId];

        if (cell.isAmputated) revert AOXCErrors.AOXC_CustomRevert("CELL_AMPUTATED");

        // V6.1 FIX: Using the correct argument order for your library
        if (msg.sender != cell.manager) {
            revert AOXCErrors.AOXC_Unauthorized(AOXCConstants.GOVERNANCE_ROLE, msg.sender);
        }

        if (block.timestamp > cell.lastReset + 1 days) {
            cell.currentVolume = 0;
            cell.lastReset = block.timestamp;
        }

        if (cell.currentVolume + amount > cell.dailyLimit) {
            cell.isAmputated = true;
            globalNeuralLock = true;
            emit NeuralLockActivated("CELL_LIMIT_BREACH");
            revert AOXCErrors.AOXC_CustomRevert("DEFENSE_TRIGGERED: LOCKDOWN");
        }

        _checkAllWalls(cellId, token, amount);

        cell.currentVolume += amount;
        IERC20(token).safeTransfer(to, amount);

        emit FundsReleased(cellId, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        EMERGENCY & ADMIN
    //////////////////////////////////////////////////////////////*/

    function emergencyEvacuate(address token, address safetyVault) external onlyRole(AOXCConstants.GUARDIAN_ROLE) {
        globalNeuralLock = true;
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(safetyVault, balance);
        }
    }

    function resetSystem() external onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        globalNeuralLock = false;
    }

    uint256[47] private _gap;
}
