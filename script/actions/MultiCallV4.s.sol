/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ActionMultiCallV4 } from "./../../src/actions/MultiCallV4.sol";

contract MultiCallV4Deployment is Test {
    uint256 internal deployer = vm.envUint("PRIVATE_KEY_PERIF_DEPLOYER_BASE");

    ActionMultiCallV4 internal multicallV4;

    function run() public {
        vm.startBroadcast(deployer);
        multicallV4 = new ActionMultiCallV4();
        vm.stopBroadcast();
    }
}
