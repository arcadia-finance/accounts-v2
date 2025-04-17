/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ActionMultiCallV8 } from "./../../src/actions/MultiCallV8.sol";

contract MultiCallV8Deployment is Test {
    uint256 internal deployer = vm.envUint("PRIVATE_KEY_PERIF_DEPLOYER_BASE");

    ActionMultiCallV8 internal multicallV8;

    function run() public {
        vm.startBroadcast(deployer);
        multicallV8 = new ActionMultiCallV8();
        vm.stopBroadcast();
    }
}
