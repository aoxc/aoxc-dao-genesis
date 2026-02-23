// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {AOXCArchitectureFinal} from "./AOXC_Architecture_Final.t.sol";

/**
 * @title AOXC 100% Coverage Final Shot
 * @notice Targets final missing branches in AOXC.sol.
 * @dev Fixed: naming convention for ignored variables to bypass Error (3726).
 */
contract AOXCFinalShot is AOXCArchitectureFinal {
    /**
     * @notice Targets: The "else" paths in _update for tax calculation.
     */
    function test_Branch_Tax_Edge_Cases() public {
        vm.startPrank(admin);
        proxy.configureTax(1, true);
        proxy.setTreasury(user1);
        deal(address(proxy), user1, 1000e18);
        vm.stopPrank();

        // BRANCH 1: Transfer FROM treasury (from == t).
        vm.prank(user1);
        bool success1 = proxy.transfer(user2, 100e18);
        assertTrue(success1);

        // BRANCH 2: Tax calculation results in zero (tax == 0).
        address poorUser = address(0x999);
        deal(address(proxy), poorUser, 1000);
        vm.prank(poorUser);
        bool success2 = proxy.transfer(user2, 10);
        assertTrue(success2);
    }

    /**
     * @notice Targets: The time-based reset in the mint function.
     */
    function test_Branch_Mint_Yearly_Reset() public {
        vm.startPrank(admin);
        proxy.mint(user1, 1000e18);

        vm.warp(block.timestamp + 366 days);

        proxy.mint(user1, 100e18);
        assertEq(proxy.mintedThisYear(), 100e18);
        vm.stopPrank();
    }

    /**
     * @notice Targets: The failure path of the rescueEth function.
     */
    function test_Branch_Rescue_Fail_Path() public {
        vm.startPrank(admin);
        proxy.grantRole(proxy.GOVERNANCE_ROLE(), address(this));
        vm.stopPrank();

        vm.deal(address(proxy), 1 ether);

        vm.prank(address(this));
        vm.expectRevert();
        proxy.rescueEth();
    }

    /**
     * @notice Targets: Blacklist check on the RECIPIENT.
     */
    function test_Branch_Blacklisted_Recipient() public {
        vm.startPrank(admin);
        proxy.addToBlacklist(user2, "Restricted");
        vm.stopPrank();

        deal(address(proxy), user1, 100e18);

        vm.prank(user1);
        vm.expectRevert();
        // We use a low-level call here to satisfy the linter and compiler simultaneously
        (bool success,) = address(proxy).call(abi.encodeWithSelector(proxy.transfer.selector, user2, 10e18));

        // Silence "unused variable" warning
        assembly {
            let x := success
        }
    }

    /**
     * @notice Targets: Maximum tax boundary check in initializeV2.
     */
    function test_Branch_TaxTooHigh_Revert() public {
        vm.prank(admin);
        vm.expectRevert();
        proxy.initializeV2(1001);
    }

    /**
     * @notice Targets: The logic for an empty treasury address (ternary operator).
     */
    function test_Branch_Treasury_Zero_Address_Default() public {
        vm.prank(admin);
        proxy.configureTax(500, true);

        deal(address(proxy), user1, 100e18);

        vm.prank(user1);
        bool success3 = proxy.transfer(user2, 10e18);
        assertTrue(success3);
    }

    // Reject ETH to force rescueEth failure
    receive() external payable {
        revert("Rejection for Test");
    }
}
