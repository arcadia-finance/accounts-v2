/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { BaseGuardian } from "../../../src/guardians/BaseGuardian.sol";

contract BaseGuardianExtension is BaseGuardian {
    function pause() external override { }

    function unpause() external override { }
}
