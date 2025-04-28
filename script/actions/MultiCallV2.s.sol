/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ActionMultiCallV2 } from "./../../src/actions/MultiCallV2.sol";

contract MultiCallV2Deployment is Test {
    uint256 internal deployer = vm.envUint("PRIVATE_KEY_DEPLOYER");

    ActionMultiCallV2 internal multicallV2;

    function run() public {
        vm.startBroadcast(deployer);
        multicallV2 = new ActionMultiCallV2();
        vm.stopBroadcast();
    }
}
