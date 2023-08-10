/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { VaultStorageV1 } from "../VaultStorageV1.sol";

contract VaultVariableVersion is VaultStorageV1 {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    uint16 public vaultVersion;

    constructor(uint256 vaultVersion_) {
        vaultVersion = uint16(vaultVersion_);
    }

    function setVaultVersion(uint256 vaultVersion_) public {
        vaultVersion = uint16(vaultVersion_);
    }
}
