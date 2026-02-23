// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "@openzeppelin/contracts-upgradeable/access/AccessManagerUpgradeable.sol";

/**
 * @title AOXC Security Registry
 * @notice DAO'nun merkezi sinir sistemi. Tüm yetkiler buradan yönetilir.
 */
contract AOXCSecurityRegistry is AccessManagerUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) public initializer {
        __AccessManager_init(admin);
    }
    
    // Acil durum dondurma fonksiyonu (Circuit Breaker)
    function triggerEmergencyStop() external {
        // Sadece yetkili komite tüm ekosistemi dondurabilir
    }
}
