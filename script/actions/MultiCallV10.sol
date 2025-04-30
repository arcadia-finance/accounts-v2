/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ActionMultiCallV10 } from "./../../src/actions/MultiCallV10.sol";

contract MultiCallV10Deployment is Test {
    uint256 internal deployer = vm.envUint("PRIVATE_KEY_PERIF_DEPLOYER_BASE");

    ActionMultiCallV10 internal multicallV10;

    function run() public {
        vm.startBroadcast(deployer);
        multicallV10 = new ActionMultiCallV10();
        vm.stopBroadcast();
    }
}
