/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ActionMultiCallV12 } from "./../../src/actions/MultiCallV12.sol";

contract MultiCallV12Deployment is Test {
    uint256 internal deployer = vm.envUint("PRIVATE_KEY_PERIF_DEPLOYER_BASE");

    ActionMultiCallV12 internal multicallV12;

    function run() public {
        vm.startBroadcast(deployer);
        multicallV12 = new ActionMultiCallV12();
        vm.stopBroadcast();
    }
}
