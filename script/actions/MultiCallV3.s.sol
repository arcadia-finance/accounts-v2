/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ActionMultiCallV3 } from "./../../src/actions/MultiCallV3.sol";

contract MultiCallV3Deployment is Test {
    uint256 internal deployer = vm.envUint("PRIVATE_KEY_DEPLOYER_BASE");

    ActionMultiCallV3 internal multicallV3;

    function run() public {
        vm.startBroadcast(deployer);
        multicallV3 = new ActionMultiCallV3();
        vm.stopBroadcast();
    }
}
