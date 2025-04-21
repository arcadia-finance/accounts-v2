/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ActionMultiCallV9 } from "./../../src/actions/MultiCallV9.sol";

contract MultiCallV9Deployment is Test {
    uint256 internal deployer = vm.envUint("PRIVATE_KEY_PERIF_DEPLOYER_BASE");

    ActionMultiCallV9 internal multicallV9;

    function run() public {
        vm.startBroadcast(deployer);
        multicallV9 = new ActionMultiCallV9();
        vm.stopBroadcast();
    }
}
