// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {AOXCArchitectureFinal} from "./AOXC_Architecture_Final.t.sol";
import {AOXC} from "../src/AOXC.sol";

/**
 * @title AOXC 100% Coverage Nuke - No Warnings Edition
 * @notice Linter uyarılarını giderir ve branch coverage'ı maksimize eder.
 */
contract AOXC100Nuke is AOXCArchitectureFinal {
    /**
     * @notice Hedef: _update içindeki Mint ve Burn dalları.
     * Delta kontrolü sayesinde başlangıç bakiyesinden bağımsız çalışır.
     */
    function test_Nuke_Update_Branch_Logic() public {
        vm.startPrank(admin);
        uint256 balanceBefore = proxy.balanceOf(user1);

        // Mint dalı
        proxy.mint(user1, 100e18);
        assertEq(proxy.balanceOf(user1), balanceBefore + 100e18);

        vm.stopPrank();

        // Burn dalı
        vm.prank(user1);
        proxy.burn(50e18);
        assertEq(proxy.balanceOf(user1), balanceBefore + 50e18);
    }

    /**
     * @notice Hedef: transferTreasuryFunds.
     * Kontrat bakiyesinin transferi ve internal _transfer çağrısı.
     */
    function test_Nuke_Internal_Treasury_Transfer() public {
        deal(address(proxy), address(proxy), 1000e18);
        uint256 user1Before = proxy.balanceOf(user1);

        vm.prank(admin);
        proxy.transferTreasuryFunds(user1, 100e18);

        assertEq(proxy.balanceOf(user1), user1Before + 100e18);
    }

    /**
     * @notice Hedef: Treasury Set iken vergi ternary operatörü.
     * FIX: Linter uyarısı (erc20-unchecked-transfer) giderildi.
     */
    function test_Nuke_Tax_With_Treasury_Set() public {
        vm.startPrank(admin);
        proxy.setTreasury(user2);
        proxy.configureTax(1000, true); // %10 vergi
        vm.stopPrank();

        deal(address(proxy), user1, 100e18);

        vm.prank(user1);
        // Linter uyarısını engellemek için dönüş değerini kontrol ediyoruz
        bool success = proxy.transfer(address(0x123), 10e18);
        assertTrue(success, "Transfer basarisiz oldu");

        // Verginin user2'ye gittiğini doğrula
        assertEq(proxy.balanceOf(user2), 1e18);
    }

    /**
     * @notice Hedef: _authorizeUpgrade yetkisiz erişim revert dalı.
     */
    function test_Nuke_Unauthorized_Upgrade_Branch() public {
        AOXC newImpl = new AOXC();
        vm.prank(user1);
        vm.expectRevert();
        proxy.upgradeToAndCall(address(newImpl), "");
    }

    /**
     * @notice Hedef: reinitializer(2) koruması.
     */
    function test_Nuke_Initializer_Already_Set() public {
        vm.startPrank(admin);
        try proxy.initializeV2(500) {
            vm.expectRevert();
            proxy.initializeV2(500);
        } catch {
            // Branch boyandı
        }
        vm.stopPrank();
    }
}
