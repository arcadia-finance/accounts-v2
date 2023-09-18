/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AccountStorageV1 } from "../../../src/AccountStorageV1.sol";

contract AccountStorageV2 is AccountStorageV1 {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    uint256 public storageV2;
}
