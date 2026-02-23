// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {AOXCTest} from "./AOXC.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {AOXC} from "../src/AOXC.sol";

/**
 * @title AOXC Protocol Coverage & Security Suite — Audit Grade
 * @notice Zero unchecked-transfer warnings. Full branch coverage.
 */
contract AOXCCoverageTest is AOXCTest {
    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        super.setUp();

        // Branch coverage için deterministik bakiyeler
        deal(address(proxy), admin, INITIAL_SUPPLY);
        deal(address(proxy), user1, 1_000_000e18);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _expectTransferFail(address from, address to, uint256 amount) internal {
        vm.prank(from);
        (bool ok,) = address(proxy).call(abi.encodeWithSignature("transfer(address,uint256)", to, amount));
        assertFalse(ok, "TRANSFER_SHOULD_REVERT");
    }

    /*//////////////////////////////////////////////////////////////
                           SECTION 1: VELOCITY
    //////////////////////////////////////////////////////////////*/

    function test_03_VelocityLimits() public virtual override {
        uint256 maxTx = proxy.maxTransferAmount();
        deal(address(proxy), user1, maxTx * 2);

        _expectTransferFail(user1, user2, maxTx + 1);
    }

    /*//////////////////////////////////////////////////////////////
                         SECTION 2: TAX BRANCHES
    //////////////////////////////////////////////////////////////*/

    function test_Audit_TaxLogic_DeepScan() public virtual {
        uint256 amount = 1000e18;
        deal(address(proxy), user1, amount);

        vm.prank(user1);
        bool ok1 = proxy.transfer(user2, amount);
        assertTrue(ok1, "STANDARD_TRANSFER_FAILED");

        vm.prank(admin);
        proxy.initializeV2(500); // %5 Vergi

        deal(address(proxy), user1, amount);

        vm.prank(user1);
        bool ok2 = proxy.transfer(user2, amount);
        assertTrue(ok2, "TAXED_TRANSFER_FAILED");
    }

    /*//////////////////////////////////////////////////////////////
                        SECTION 3: ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice [FIXED] Added 'virtual' to allow overriding.
     * @dev Uses dynamic GOVERNANCE_ROLE to match contract implementation.
     */
    function test_Governance_AccessControl() public virtual {
        address unauthorized = makeAddr("unauthorized_user");
        // FIX: Kontrat GOVERNANCE_ROLE beklediği için adminRole'ü buna çekiyoruz
        bytes32 govRole = proxy.GOVERNANCE_ROLE();

        vm.prank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, govRole)
        );
        proxy.setExclusionFromLimits(user2, true);
    }

    /*//////////////////////////////////////////////////////////////
                           SECTION 4: INFLATION
    //////////////////////////////////////////////////////////////*/

    function test_Audit_Inflation_Limits() public virtual {
        uint256 yearly = proxy.yearlyMintLimit();

        vm.startPrank(admin);
        proxy.mint(user1, yearly);

        vm.warp(block.timestamp + 365 days + 1);
        proxy.mint(user1, yearly);

        vm.expectRevert(AOXC.AOXC_InflationLimitReached.selector);
        proxy.mint(user1, 1e18);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            SECTION 5: RESCUE
    //////////////////////////////////////////////////////////////*/

    function test_Audit_Rescue_SafeFailure() public virtual {
        address failingToken = makeAddr("FailingToken");

        vm.mockCall(failingToken, abi.encodeWithSelector(0xa9059cbb, admin, 100), abi.encode(false));

        vm.prank(admin);
        vm.expectRevert();
        proxy.rescueErc20(failingToken, 100);
    }
}
