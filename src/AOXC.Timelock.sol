// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// SENİN TREE ÇIKTINA GÖRE DOĞRU YOL: utils klasörü yok
import {
    TimelockControllerUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";

/**
 * @title AOXC Timelock Controller
 * @notice AOXC ekosisteminin gerçek "Admin"i. Kararları bekletir ve güvenliği sağlar.
 */
contract AOXCTimelock is Initializable, TimelockControllerUpgradeable, UUPSUpgradeable {
    /*//////////////////////////////////////////////////////////////
                                CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/
    error AOXC_InvalidAdminAddress();
    error AOXC_MinDelayTooShort();
    error AOXC_UnauthorizedUpgrade();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Timelock'ı başlatır.
     * @param minDelay Önerinin yürütülmesi için gereken minimum süre (saniye).
     * @param proposers Öneri sunabilecek adresler (Genelde Governor adresi).
     * @param executors Öneriyi yürütebilecek adresler (Genelde address(0)).
     * @param admin Admin rolü (Multi-sig veya DAO'nun kendisi).
     */
    function initialize(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
        public
        initializer
    {
        if (admin == address(0)) revert AOXC_InvalidAdminAddress();
        if (minDelay < 1 hours) revert AOXC_MinDelayTooShort();

        __TimelockController_init(minDelay, proposers, executors, admin);
        __UUPSUpgradeable_init();
    }

    /*//////////////////////////////////////////////////////////////
                            UPGRADE PROTECTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Kontratın güncellenmesi için yetki kontrolü.
     * Sadece Timelock'ın kendisi (yani DAO kararı geçerse) kendini güncelleyebilir.
     */
    function _authorizeUpgrade(address newImplementation) internal override {
        if (msg.sender != address(this)) revert AOXC_UnauthorizedUpgrade();
    }

    /*//////////////////////////////////////////////////////////////
                            STORAGE PROTECTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Gelecekte eklenecek değişkenler için yer tutucu.
     */
    uint256[49] private __gap;
}
