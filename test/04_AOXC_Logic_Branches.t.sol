// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {AOXCArchitectureFinal} from "./AOXC_Architecture_Final.t.sol";

/**
 * @title AOXC Logic Branches
 * @notice _update fonksiyonundaki if/else dallarını (branch) hedefler ve lint hatalarını giderir.
 */
contract AOXCLogicBranches is AOXCArchitectureFinal {
    /**
     * @dev Branch: Transfer from treasury (Tax skip logic)
     * Hazine gönderici olduğunda tax uygulanmamalı.
     */
    function test_Branch_Treasury_As_Sender() public {
        vm.prank(admin);
        proxy.setTreasury(treasury);

        uint256 amount = 100e18;
        deal(address(proxy), treasury, amount);

        uint256 preBalance = proxy.balanceOf(user1);

        vm.prank(treasury);
        bool success = proxy.transfer(user1, amount); // FIX: bool success eklendi (Lint Fix)
        assertTrue(success);

        // Hazine gönderdiği için tam miktar geçmeli
        assertEq(proxy.balanceOf(user1) - preBalance, amount, "Treasury sender tax skip failed");
    }

    /**
     * @dev Branch: Transfer to treasury (Tax skip logic)
     */
    function test_Branch_Treasury_As_Recipient() public {
        uint256 amount = 100e18;
        deal(address(proxy), user1, amount);

        uint256 preTreasury = proxy.balanceOf(treasury);

        vm.prank(user1);
        bool success = proxy.transfer(treasury, amount); // FIX: bool success eklendi (Lint Fix)
        assertTrue(success);

        assertEq(proxy.balanceOf(treasury) - preTreasury, amount, "Treasury recipient tax skip failed");
    }

    /**
     * @dev Branch: Self-transfer logic
     */
    function test_Branch_Update_SelfTransfer() public {
        deal(address(proxy), user1, 100e18);
        uint256 preTreasury = proxy.balanceOf(treasury);

        vm.startPrank(user1);
        bool success = proxy.transfer(user1, 10e18);
        assertTrue(success);

        // Toplam bakiye (Kullanıcı + Hazine) değişmemeli
        assertEq(proxy.balanceOf(user1) + proxy.balanceOf(treasury), 100e18 + preTreasury);
        vm.stopPrank();
    }

    /**
     * @dev Branch: Tax is disabled (0 basis points)
     */
    function test_Branch_Tax_Disabled_Path() public {
        vm.prank(admin);
        proxy.initializeV2(0);

        deal(address(proxy), user1, 100e18);
        uint256 preUser2 = proxy.balanceOf(user2);

        vm.prank(user1);
        bool success = proxy.transfer(user2, 10e18); // FIX: bool success eklendi (Lint Fix)
        assertTrue(success);

        assertEq(proxy.balanceOf(user2) - preUser2, 10e18, "Zero tax path failed");
    }
}
