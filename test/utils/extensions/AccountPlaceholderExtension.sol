/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountPlaceholder } from "../../../src/accounts/AccountPlaceholder.sol";

contract AccountPlaceholderExtension is AccountPlaceholder {
    constructor(address factory, address accountsGuard, uint256 version)
        AccountPlaceholder(factory, accountsGuard, version)
    { }

    function setLastActionTimestamp(uint32 lastActionTimestamp_) external {
        lastActionTimestamp = lastActionTimestamp_;
    }

    function setOwner(address newOwner) public {
        owner = newOwner;
    }

    function setRegistry(address registry_) public {
        registry = registry_;
    }

    function getCoolDownPeriod() public pure returns (uint256 coolDownPeriod) {
        coolDownPeriod = COOL_DOWN_PERIOD;
    }
}
