/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ActionMultiCallV7 } from "./../../src/actions/MultiCallV7.sol";

contract MultiCallV7Deployment is Test {
    uint256 internal deployer = vm.envUint("PRIVATE_KEY_PERIF_DEPLOYER_BASE");

    ActionMultiCallV7 internal multicallV7;

    function run() public {
        vm.startBroadcast(deployer);
        multicallV7 = new ActionMultiCallV7();
        vm.stopBroadcast();
    }
}
