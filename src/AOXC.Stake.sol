// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAOXC is IERC20 {
    function burn(uint256 amount) external;
}

/**
 * @title AOXC Tiered Staking with Deflationary Burn
 * @notice Features 3, 6, 9, 12 month tiers with a 6% APR.
 * @dev Audit Note: Early withdrawal results in 100% principal burn.
 */
contract AOXCStaking is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 lockDuration;
        bool active;
    }

    IAOXC public stakingToken;
    uint256 public constant ANNUAL_REWARD_BPS = 600; // 6%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant SECONDS_IN_YEAR = 365 days;

    mapping(address => Stake[]) public userStakes;

    error InvalidDuration();
    error StakeNotFound();
    error AlreadyWithdrawn();
    error UnauthorizedUpgrade();
    error InsufficientContractBalance();

    event Staked(address indexed user, uint256 amount, uint256 duration);
    event Withdrawn(address indexed user, uint256 amountReturned, uint256 amountBurned);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _token, address _governor) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        stakingToken = IAOXC(_token);
        _grantRole(DEFAULT_ADMIN_ROLE, _governor);
        _grantRole(GOVERNANCE_ROLE, _governor);
        _grantRole(UPGRADER_ROLE, _governor);
    }

    /**
     * @notice Creates a new stake.
     * @param _amount Amount of AOXC to stake.
     * @param _months Tier: 3, 6, 9, or 12.
     */
    function stake(uint256 _amount, uint256 _months) external nonReentrant {
        uint256 duration;
        if (_months == 3) duration = 90 days;
        else if (_months == 6) duration = 180 days;
        else if (_months == 9) duration = 270 days;
        else if (_months == 12) duration = 360 days;
        else revert InvalidDuration();

        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        userStakes[msg.sender].push(
            Stake({amount: _amount, startTime: block.timestamp, lockDuration: duration, active: true})
        );

        emit Staked(msg.sender, _amount, duration);
    }

    /**
     * @notice Withdraws principal and rewards.
     * @dev If early, principal is BURNED. Rewards are only paid if contract has funds.
     */
    function withdraw(uint256 _stakeIndex) external nonReentrant {
        if (_stakeIndex >= userStakes[msg.sender].length) revert StakeNotFound();

        Stake storage s = userStakes[msg.sender][_stakeIndex];
        if (!s.active) revert AlreadyWithdrawn();

        uint256 elapsedTime = block.timestamp - s.startTime;

        // High-precision reward calculation: (Principal * BPS * Time) / (10000 * 365 days)
        uint256 reward = (s.amount * ANNUAL_REWARD_BPS * elapsedTime) / (BPS_DENOMINATOR * SECONDS_IN_YEAR);

        uint256 amountToReturn;
        uint256 amountToBurn;

        s.active = false; // CEI Pattern: Set inactive before transfers

        if (elapsedTime >= s.lockDuration) {
            // MATURED: Return Principal + Reward
            amountToReturn = s.amount + reward;
        } else {
            // EARLY: Burn Principal, Return only Reward
            amountToReturn = reward;
            amountToBurn = s.amount;
        }

        // Safety check: Ensure contract has enough AOXC for the reward/return
        uint256 contractBalance = stakingToken.balanceOf(address(this));
        if (amountToReturn > contractBalance) {
            // If contract is dry, return at least what we can (Audit fallback)
            amountToReturn = contractBalance > s.amount ? s.amount : contractBalance;
        }

        if (amountToBurn > 0) {
            stakingToken.burn(amountToBurn);
        }

        if (amountToReturn > 0) {
            stakingToken.safeTransfer(msg.sender, amountToReturn);
        }

        emit Withdrawn(msg.sender, amountToReturn, amountToBurn);
    }

    /**
     * @dev Get total number of stakes for a user.
     */
    function getStakeCount(address _user) external view returns (uint256) {
        return userStakes[_user].length;
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    // Storage gap for upgradeability
    uint256[46] private __gap;
}
