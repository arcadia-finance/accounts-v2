/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ActionMultiCallV11 } from "./../../src/actions/MultiCallV11.sol";

contract MultiCallV11Deployment is Test {
    uint256 internal deployer = vm.envUint("PRIVATE_KEY_PERIF_DEPLOYER_BASE");

    ActionMultiCallV11 internal multicallV11;

    function run() public {
        vm.startBroadcast(deployer);
        multicallV11 = new ActionMultiCallV11();
        vm.stopBroadcast();
    }
}
