/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountStorageV1 } from "../../../../src/accounts/AccountStorageV1.sol";

contract AccountVariableVersion is AccountStorageV1 {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    /// forge-lint: disable-start(mixed-case-variable)
    uint16 public ACCOUNT_VERSION;
    address public FACTORY;
    /// forge-lint: disable-end(mixed-case-variable)

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
