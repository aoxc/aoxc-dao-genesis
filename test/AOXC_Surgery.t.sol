// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {AOXC} from "../src/AOXC.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/*//////////////////////////////////////////////////////////////
                        MOCK TOKEN
//////////////////////////////////////////////////////////////*/

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/*//////////////////////////////////////////////////////////////
                        AOXC SURGERY TEST
//////////////////////////////////////////////////////////////*/

contract AOXCSurgeryTest is Test {
    AOXC public proxy;

    address public admin = makeAddr("admin");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public complianceOfficer = makeAddr("compliance");

    uint256 internal constant INITIAL_SUPPLY = 100_000_000_000 * 1e18;

    function setUp() public {
        AOXC implementation = new AOXC();
        bytes memory initData = abi.encodeWithSelector(AOXC.initialize.selector, admin);
        proxy = AOXC(address(new ERC1967Proxy(address(implementation), initData)));

        vm.startPrank(admin);
        proxy.grantRole(proxy.COMPLIANCE_ROLE(), complianceOfficer);

        // Success path → assert return value to satisfy linter
        bool funded = proxy.transfer(user1, 1_000_000e18);
        assertTrue(funded, "SETUP_FUNDING_FAILED");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    INTERNAL LINT-SAFE HELPERS
    //////////////////////////////////////////////////////////////*/

    function _assertTransferOk(address from, address to, uint256 amount) internal {
        vm.prank(from);
        bool ok = proxy.transfer(to, amount);
        assertTrue(ok, "ERC20_TRANSFER_FAILED");
    }

    function _assertTransferReverts(address from, address to, uint256 amount, bytes memory revertData) internal {
        vm.prank(from);
        vm.expectRevert(revertData);
        // Low-level call to bypass compiler analysis of return value
        (bool success,) = address(proxy).call(abi.encodeWithSelector(proxy.transfer.selector, to, amount));
        // We expect 'success' to be false, but Forge's expectRevert handles the check.
        // We consume 'success' to avoid "unused variable" warnings.
        success;
    }

    /*//////////////////////////////////////////////////////////////
                        STATE INVARIANTS
    //////////////////////////////////////////////////////////////*/

    function testStateTotalSupplyInvariant() public view {
        assertEq(proxy.totalSupply(), INITIAL_SUPPLY, "TOTAL_SUPPLY_MUTATED");
    }

    /*//////////////////////////////////////////////////////////////
                        BLACKLIST ENFORCEMENT
    //////////////////////////////////////////////////////////////*/

    function testBlacklistEnforcementAudit() public {
        vm.prank(complianceOfficer);
        proxy.addToBlacklist(user1, "AML investigation");

        _assertTransferReverts(user1, user2, 100e18, bytes("AOXC: sender blacklisted"));
    }

    /*//////////////////////////////////////////////////////////////
                        DAILY LIMIT & WINDOW RESET
    //////////////////////////////////////////////////////////////*/

    function testDailyLimitResetAudit() public {
        uint256 dailyLimit = 1_000e18;
        uint256 maxTx = 5_000e18;

        vm.prank(admin);
        proxy.setTransferVelocity(maxTx, dailyLimit);

        _assertTransferOk(user1, user2, dailyLimit);
        _assertTransferReverts(user1, user2, 1, bytes("AOXC: daily limit"));

        vm.warp(block.timestamp + 25 hours);
        _assertTransferOk(user1, user2, 100e18);
    }

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice [FIXED] Aligns with actual GOVERNANCE_ROLE requirement.
     */
    function testAccessControlUnauthorizedAudit() public {
        // Hata buradaydı: setExclusionFromLimits GOVERNANCE_ROLE gerektirir
        bytes32 govRole = proxy.GOVERNANCE_ROLE();

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user2, govRole)
        );
        proxy.setExclusionFromLimits(user1, true);
    }

    /*//////////////////////////////////////////////////////////////
                        ERC20 RESCUE LOGIC
    //////////////////////////////////////////////////////////////*/

    function testRescueERC20Audit() public {
        MockToken foreignToken = new MockToken();
        uint256 rescueAmount = 500e18;
        foreignToken.mint(address(proxy), rescueAmount);

        uint256 adminBefore = foreignToken.balanceOf(admin);

        vm.prank(admin);
        proxy.rescueErc20(address(foreignToken), rescueAmount);

        assertEq(foreignToken.balanceOf(address(proxy)), 0, "RESCUE_INCOMPLETE");
        assertEq(foreignToken.balanceOf(admin), adminBefore + rescueAmount, "ADMIN_NOT_FUNDED");
    }
}
