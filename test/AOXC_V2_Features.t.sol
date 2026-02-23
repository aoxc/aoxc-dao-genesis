// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {AOXC} from "../src/AOXC.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract AOXCV2FeaturesTest is Test {
    AOXC public proxy;
    address public admin = makeAddr("admin");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public treasury = makeAddr("treasury");

    function setUp() public {
        AOXC implementation = new AOXC();
        bytes memory initData = abi.encodeWithSelector(AOXC.initialize.selector, admin);
        proxy = AOXC(address(new ERC1967Proxy(address(implementation), initData)));

        vm.startPrank(admin);
        proxy.mint(user1, 10_000e18);
        proxy.setTreasury(treasury);
        vm.stopPrank();
    }

    /**
     * @notice [FIXED] Linter warnings silenced and Role Hash corrected.
     */
    function test_Revert_Unauthorized_With_Selector() public {
        // Hata buradaydı: configureTax için GOVERNANCE_ROLE gerekir.
        bytes32 govRole = proxy.GOVERNANCE_ROLE();

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user2, govRole)
        );
        // Low-level call to satisfy linter for revert paths
        (bool success,) = address(proxy).call(abi.encodeWithSelector(proxy.configureTax.selector, 500, true));
        success;
    }

    function test_TaxMechanism_Cumulative_Success() public {
        vm.prank(admin);
        proxy.configureTax(1000, true); // %10 vergi

        uint256 amount = 1000e18;
        uint256 expectedTax = 100e18;

        vm.prank(user1);
        // Success path: Assert return value to satisfy linter
        bool ok = proxy.transfer(user2, amount);
        assertTrue(ok, "TRANSFER_FAILED");

        assertEq(proxy.balanceOf(treasury), expectedTax);
        assertEq(proxy.balanceOf(user2), amount - expectedTax);
    }

    function test_LockOverwrite_Logic() public {
        vm.startPrank(admin);
        proxy.lockUserFunds(user1, 1 days);
        proxy.lockUserFunds(user1, 2 days); // Overwrite
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert();
        (bool ok,) = address(proxy).call(abi.encodeWithSelector(proxy.transfer.selector, user2, 10e18));
        ok;
    }

    function test_TaxExemption_For_Admin() public {
        vm.prank(admin);
        proxy.configureTax(1000, true);

        vm.prank(admin);
        bool ok = proxy.transfer(user2, 1000e18);
        assertTrue(ok);

        // Admin vergi ödemez
        assertEq(proxy.balanceOf(treasury), 0);
    }

    function test_TreasuryFundTransfer() public {
        vm.prank(admin);
        proxy.mint(treasury, 5000e18);

        vm.prank(treasury);
        bool ok = proxy.transfer(user2, 1000e18);
        assertTrue(ok);

        // Treasury transferlerinde vergi kesilmez
        assertEq(proxy.balanceOf(treasury), 4000e18);
    }
}
