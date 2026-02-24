// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/*//////////////////////////////////////////////////////////////
    ___   ____ _  ________   ______ ____  ____  ______
   /   | / __ \ |/ / ____/  / ____// __ \/ __ \/ ____/
  / /| |/ / / /   / /      / /    / / / / /_/ / __/
 / ___ / /_/ /   / /___   / /___ / /_/ / _, _/ /___
/_/  |_\____/_/|_\____/   \____/ \____/_/ |_/_____/

    Sovereign Protocol Infrastructure | Core Library
//////////////////////////////////////////////////////////////*/

/**
 * @title AOXC Protocol Constants
 * @author AOXC Protocol Team
 * @notice Centralized repository for protocol-wide constants and DAO storage keys.
 * @dev Optimized with inline assembly to ensure maximum gas efficiency and zero linter warnings.
 */
library AOXCConstants {
    /*//////////////////////////////////////////////////////////////
                            METADATA & VERSION
    //////////////////////////////////////////////////////////////*/

    /// @notice Official protocol versioning following SemVer standards.
    string public constant PROTOCOL_VERSION = "2.6.0-Sovereign-Final";

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL ROLES
    //////////////////////////////////////////////////////////////*/

    /// @dev Roles defined as keccak256 hashes for AccessControl compatibility.
    bytes32 public constant GOVERNANCE_ROLE = 0x71840dc4906352362b0cdaf79870196c8e42ac92e40a2d57220dad45a6dbac7c;
    bytes32 public constant GUARDIAN_ROLE = 0x55435dd261a4b9b3364d10f7a39b973783c0e58f8ca56ad36bb973516890d148;
    bytes32 public constant BRIDGE_ROLE = 0x1993e17409252bc06368d44778393e82d8c3639ca6a941e9c805a41505c2494c;
    bytes32 public constant UPGRADER_ROLE = 0x189ab97c413346e9196d420556a3196924294086699d75b33190df09b55502c4;
    bytes32 public constant MINTER_ROLE = 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;
    bytes32 public constant COMPLIANCE_ROLE = 0xf279e6566679589a19c9940177726715b9c0879f64c63283624f9f74a00445d0;
    bytes32 public constant TREASURY_ROLE = 0x3673323c316238b975d691ee9eb2907471904a0808a342427a1599386d3e6486;

    /*//////////////////////////////////////////////////////////////
                            TIME STANDARDS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ONE_HOUR = 3600;
    uint256 public constant ONE_DAY = 86400;
    uint256 public constant ONE_YEAR = 31536000;

    /// @notice Minimum lock duration for staking (30 Days).
    uint256 public constant MIN_STAKE_DURATION = 30 days;

    uint256 public constant MIN_VOTING_DELAY = 1 days;
    uint256 public constant MAX_VOTING_PERIOD = 14 days;

    /*//////////////////////////////////////////////////////////////
                            FINANCIAL LIMITS
    //////////////////////////////////////////////////////////////*/

    /// @dev Basis Points (BPS) denominator for percentage calculations.
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_TAX_BPS = 1_000; // 10%
    uint256 public constant ANNUAL_CAP_BPS = 600; // 6%

    uint256 public constant MAX_SINGLE_TX_LIMIT = 5_000_000_000 * 1e18;
    uint256 public constant MIN_DUST_THRESHOLD = 1e15;

    /*//////////////////////////////////////////////////////////////
                            INFRASTRUCTURE
    //////////////////////////////////////////////////////////////*/

    /// @dev Official X-Layer Chain ID for cross-chain routing.
    uint16 public constant CHAIN_ID_X_LAYER = 196;
    uint256 public constant DEFAULT_DAILY_BRIDGE_LIMIT = 1_000_000 * 1e18;

    /*//////////////////////////////////////////////////////////////
                        DYNAMIC STORAGE KEYS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Keys used for dynamic parameter mapping in core storage modules.
     */
    bytes32 public constant DYNAMIC_MAX_SUPPLY_KEY = keccak256("AOXC.PARAM.MAX_SUPPLY");
    bytes32 public constant DYNAMIC_TAX_FREE_KEY = keccak256("AOXC.PARAM.TAX_FREE_LIMIT");
    bytes32 public constant DYNAMIC_GAS_PRICE_KEY = keccak256("AOXC.PARAM.MAX_GAS");

    /*//////////////////////////////////////////////////////////////
                            UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Generates a unique role identifier via assembly.
     * @dev Bypasses 'asm-keccak256' linting notes and saves gas on call.
     */
    function generateRole(string calldata roleName) internal pure returns (bytes32 result) {
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, roleName.offset, roleName.length)
            result := keccak256(ptr, roleName.length)
        }
    }

    /**
     * @notice Generates a storage key for dynamic protocol parameters.
     */
    function generateParamKey(string calldata paramName) internal pure returns (bytes32 result) {
        bytes memory prefix = "AOXC.DYNAMIC.";
        bytes memory combined = abi.encodePacked(prefix, paramName);

        assembly {
            result := keccak256(add(combined, 32), mload(combined))
        }
    }
}
