/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Factory } from "../../../src/Factory.sol";

contract FactoryExtension is Factory {
    function setLatestAccountVersion(uint88 latestAccountVersion_) external {
        latestAccountVersion = latestAccountVersion_;
    }
}
