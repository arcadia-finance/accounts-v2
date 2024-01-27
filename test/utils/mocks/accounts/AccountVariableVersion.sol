/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountStorageV1 } from "../../../../src/accounts/AccountStorageV1.sol";

contract AccountVariableVersion is AccountStorageV1 {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    uint16 public ACCOUNT_VERSION;
    address public FACTORY;

    constructor(uint256 accountVersion_, address factory) {
        ACCOUNT_VERSION = uint16(accountVersion_);
        FACTORY = factory;
    }

    function setAccountVersion(uint256 accountVersion_) public {
        ACCOUNT_VERSION = uint16(accountVersion_);
    }

    function setFactory(address factory) public {
        FACTORY = factory;
    }
}
