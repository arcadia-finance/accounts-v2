/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { RegistryGuardian } from "../../../src/guardians/RegistryGuardian.sol";

contract RegistryGuardianExtension is RegistryGuardian {
    constructor() RegistryGuardian() { }

    function setPauseTimestamp(uint96 pauseTimestamp_) public {
        pauseTimestamp = pauseTimestamp_;
    }

    function setFlags(bool withdrawPaused_, bool depositPaused_) public {
        withdrawPaused = withdrawPaused_;
        depositPaused = depositPaused_;
    }
}
