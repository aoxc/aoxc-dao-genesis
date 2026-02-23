// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {AOXC} from "../src/AOXC.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AOXCFullCoverage is Test {
    AOXC public proxy;
    address public admin = makeAddr("admin");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    function setUp() public {
        vm.startPrank(admin);
        AOXC impl = new AOXC();
        bytes memory data = abi.encodeWithSelector(AOXC.initialize.selector, admin);
        proxy = AOXC(address(new ERC1967Proxy(address(impl), data)));
        proxy.grantRole(keccak256("COMPLIANCE_ROLE"), admin);
        proxy.mint(user1, 1000e18);
        vm.stopPrank();
    }

    // LINTER UYARILARINI SİLEN VE COVERAGE ARTIRAN TEST
    function test_Final_Audit_Cleanup() public {
        vm.startPrank(user1);

        // Unchecked transfer uyarısını susturan yöntem:
        bool s1 = proxy.transfer(user2, 10e18);
        assertTrue(s1, "Transfer failed");

        // Coverage Artırma: Kendi kendine transfer (Self-transfer branch)
        bool s2 = proxy.transfer(user1, 5e18);
        assertTrue(s2);

        vm.stopPrank();

        // Coverage Artırma: Zero amount transfer branch
        vm.prank(user1);
        bool s3 = proxy.transfer(user2, 0);
        assertTrue(s3);
    }

    function test_Naming_Convention_Fix() public {
        // mixed-case-variable uyarısını bu ismi kullanarak çözüyoruz
        address unauthorizedUser = makeAddr("unauthorized");
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        proxy.mint(unauthorizedUser, 100e18);
    }
}
