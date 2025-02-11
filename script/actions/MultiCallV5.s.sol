/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ActionMultiCallV5 } from "./../../src/actions/MultiCallV5.sol";

contract MultiCallV5Deployment is Test {
    uint256 internal deployer = vm.envUint("PRIVATE_KEY_PERIF_DEPLOYER_BASE");

    ActionMultiCallV5 internal multicallV5;

    function run() public {
        vm.startBroadcast(deployer);
        multicallV5 = new ActionMultiCallV5();
        vm.stopBroadcast();
    }
}
