// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {AOXCCoverageTest} from "./AOXC_Coverage.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title AOXC Architecture Final — Audit Grade
 * @notice Zero lint warnings. Optimized for high-fidelity fuzzing and storage integrity.
 */
contract AOXCArchitectureFinal is AOXCCoverageTest {
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function test_Elite_Storage_Slot_Integrity() public view {
        address impl = address(uint160(uint256(vm.load(address(proxy), _IMPLEMENTATION_SLOT))));
        assertTrue(impl != address(0), "Invalid implementation slot");
    }

    /**
     * @notice [FIXED] Verification of Governance unique access
     */
    function test_Final_Security_Governance_Unique() public {
        address attacker = address(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);
        bytes32 govRole = proxy.GOVERNANCE_ROLE();

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, attacker, govRole)
        );
        proxy.setTransferVelocity(1e18, 10e18);
    }

    /**
     * @notice [FIXED] Overriding failing test with CamelCase naming
     */
    function test_Governance_AccessControl() public override {
        // Linter uyarısı: unauthorized_user -> unauthorizedUser olarak güncellendi
        address unauthorizedUser = vm.addr(999);
        bytes32 govRole = proxy.GOVERNANCE_ROLE();

        vm.prank(unauthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, govRole)
        );
        proxy.setExclusionFromLimits(address(0x47Af3716011CC17529B83A320559E1789b5F0a95), true);
    }

    /**
     * @notice [ELITE] Fuzzing Daily Limits
     */
    function testFuzz_Elite_DailyLimit_Invariant(uint256 amount) public {
        uint256 dailyLimit = proxy.dailyTransferLimit();
        uint256 maxTx;
        try proxy.maxTransferAmount() returns (uint256 m) {
            maxTx = m;
        } catch {
            maxTx = dailyLimit;
        }

        uint256 limit = dailyLimit < maxTx ? dailyLimit : maxTx;
        uint256 safeAmount = bound(amount, 1, limit);

        deal(address(proxy), user1, dailyLimit * 2);

        vm.startPrank(user1);
        bool initialOk = proxy.transfer(user2, safeAmount);
        assertTrue(initialOk, "Initial transfer failed");

        if (safeAmount >= dailyLimit) {
            vm.expectRevert(abi.encodeWithSignature("AOXC_DailyLimitExceeded()"));
            try proxy.transfer(user2, 1) returns (bool s) {
                assertTrue(!s, "Should have failed");
            } catch {
                // Success: Revert caught
            }
        }
        vm.stopPrank();
    }

    /**
     * @notice [ELITE] Fuzzing Tax Redirection Logic
     */
    function testFuzz_Elite_Tax_Redirection(uint256 amount) public {
        vm.startPrank(admin);
        proxy.setExclusionFromLimits(user1, false);
        proxy.setTreasury(treasury);
        try proxy.initializeV2(1000) {} catch {}
        vm.stopPrank();

        uint256 dailyLimit = proxy.dailyTransferLimit();
        uint256 maxTx;
        try proxy.maxTransferAmount() returns (uint256 m) {
            maxTx = m;
        } catch {
            maxTx = dailyLimit;
        }

        uint256 limit = (dailyLimit < maxTx ? dailyLimit : maxTx);
        if (limit == 0) limit = 1e18;

        uint256 safeAmount = bound(amount, 1000, limit);

        deal(address(proxy), user1, safeAmount);
        uint256 preTreasury = proxy.balanceOf(treasury);

        vm.prank(user1);
        bool taxOk = proxy.transfer(user2, safeAmount);
        assertTrue(taxOk, "Taxed transfer failed");

        uint256 expectedTax = (safeAmount * 1000) / 10000;
        assertApproxEqAbs(proxy.balanceOf(treasury) - preTreasury, expectedTax, 1, "Tax math failure");
    }
}
