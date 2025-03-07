/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ActionMultiCallV6 } from "./../../src/actions/MultiCallV6.sol";

contract MultiCallV6Deployment is Test {
    uint256 internal deployer = vm.envUint("PRIVATE_KEY_PERIF_DEPLOYER_BASE");

    ActionMultiCallV6 internal multicallV6;

    function run() public {
        vm.startBroadcast(deployer);
        multicallV6 = new ActionMultiCallV6();
        vm.stopBroadcast();
    }
}
