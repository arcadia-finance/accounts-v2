/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountSpot } from "../../../src/accounts/AccountSpot.sol";

contract AccountSpotExtension is AccountSpot {
    constructor(address factory) AccountSpot(factory) { }

    function getLocked() external view returns (uint256 locked_) {
        locked_ = locked;
    }

    function setLocked(uint8 locked_) external {
        locked = locked_;
    }

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
