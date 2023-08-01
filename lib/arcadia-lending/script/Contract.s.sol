// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Script.sol";

import { LendingPool } from "src/LendingPool.sol";

contract LendingPoolScript is Script {
    function setUp() public { }

    function run() public {
        vm.broadcast();
        //new LendingPool();
    }
}
