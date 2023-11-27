/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StandardERC20AssetModule_Fuzz_Test } from "./_StandardERC20AssetModule.fuzz.t.sol";

import { StandardERC20AssetModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "StandardERC20AssetModule".
 */
contract Constructor_StandardERC20AssetModule_Fuzz_Test is StandardERC20AssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC20AssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_) public {
        vm.startPrank(users.creatorAddress);
        StandardERC20AssetModuleExtension erc20AssetModule_ = new StandardERC20AssetModuleExtension(registry_);
        vm.stopPrank();

        assertEq(erc20AssetModule_.REGISTRY(), registry_);
        assertEq(erc20AssetModule_.ASSET_TYPE(), 0);
    }
}
