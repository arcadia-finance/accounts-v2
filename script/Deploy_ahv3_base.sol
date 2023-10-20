/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import "../lib/forge-std/src/Test.sol";

import { MainRegistry } from "../src/MainRegistry.sol";

import { ActionMultiCallV3 } from "../src/actions/MultiCallV3.sol";

contract ArcadiaMultiCallDeployment is Test {
    ActionMultiCallV3 public actionMultiCall;

    constructor() { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_BASE");

        MainRegistry mainRegistry = MainRegistry(0x64A6B6A439344Ecfd003e21216d30A61E91c25a5);

        vm.startBroadcast(deployerPrivateKey);
        actionMultiCall = new ActionMultiCallV3();
        mainRegistry.setAllowedAction(address(actionMultiCall), true);

        vm.stopBroadcast();
    }
}
