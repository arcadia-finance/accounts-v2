/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../../Base.s.sol";

import { AccountSpot } from "../../../src/accounts/AccountSpot.sol";

contract AddSpotAccountsStep1 is Base_Script {
    constructor() { }

    function run() public {
        vm.startBroadcast(deployer);
        new AccountSpot(address(factory));
        vm.stopBroadcast();
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
