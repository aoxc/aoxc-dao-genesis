// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {AOXCArchitectureFinal} from "./AOXC_Architecture_Final.t.sol";
import {AOXC} from "../src/AOXC.sol";

/**
 * @title AOXC 100% Sniper - Fixed Math
 * @notice Matematiksel hataları giderilmiş ve linter uyarıları susturulmuş son sürüm.
 */
contract AOXC100Sniper is AOXCArchitectureFinal {
    /**
     * @notice Hedef: _update içindeki Mint, Burn ve Self-Transfer dalları.
     */
    function test_Sniper_Branch_Update_Deep_Scan() public {
        vm.startPrank(admin);
        uint256 balanceBefore = proxy.balanceOf(user1);

        proxy.mint(user1, 100e18);
        assertEq(proxy.balanceOf(user1), balanceBefore + 100e18);

        vm.stopPrank();
        vm.prank(user1);
        proxy.burn(50e18);
        assertEq(proxy.balanceOf(user1), balanceBefore + 50e18);

        vm.prank(user1);
        bool success = proxy.transfer(user1, 10e18);
        assertTrue(success);
    }

    /**
     * @notice Hedef: Tax ternary operatörünün 'else' dalı (treasury != address(0)).
     */
    function test_Sniper_Branch_Tax_With_Real_Treasury() public {
        vm.startPrank(admin);
        proxy.setTreasury(user2);
        proxy.configureTax(500, true);
        vm.stopPrank();

        deal(address(proxy), user1, 100e18);

        vm.prank(user1);
        bool success = proxy.transfer(address(0xDEAD), 10e18);
        assertTrue(success);

        // Vergi user2'ye gitti mi?
        assertEq(proxy.balanceOf(user2), 0.5e18);
    }

    /**
     * @notice Hedef: _authorizeUpgrade yetkisiz erişim (AccessControl false dalı).
     */
    function test_Sniper_Branch_Upgrade_Unauthorized_Revert() public {
        AOXC newImpl = new AOXC();
        vm.prank(user2);
        vm.expectRevert();
        proxy.upgradeToAndCall(address(newImpl), "");
    }

    /**
     * @notice Hedef: transferTreasuryFunds (Delta bazlı kontrol).
     * FIX: Başlangıç bakiyesini hesaba katar.
     */
    function test_Sniper_Branch_Treasury_Funds_Zero_Check() public {
        // Kontratın kendisine 1000 token tanımla
        deal(address(proxy), address(proxy), 1000e18);

        uint256 user1Before = proxy.balanceOf(user1);

        vm.prank(admin);
        proxy.transferTreasuryFunds(user1, 100e18);

        // Toplam bakiye = Eski bakiye + 100
        assertEq(proxy.balanceOf(user1), user1Before + 100e18);
    }

    /**
     * @notice Hedef: rescueEth (address.call(0) dalı).
     */
    function test_Sniper_Branch_Rescue_Empty_State() public {
        vm.prank(admin);
        proxy.rescueEth();
    }
}
