/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AccountStorageV1 } from "../AccountStorageV1.sol";

contract AccountVariableVersion is AccountStorageV1 {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    uint16 public ACCOUNT_VERSION;

    constructor(uint256 accountVersion_) {
        ACCOUNT_VERSION = uint16(accountVersion_);
    }

    function setAccountVersion(uint256 accountVersion_) public {
        ACCOUNT_VERSION = uint16(accountVersion_);
    }
}
