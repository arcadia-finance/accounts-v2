/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20PrimaryAssetModule_Fuzz_Test } from "./_ERC20PrimaryAssetModule.fuzz.t.sol";

import { ERC20PrimaryAssetModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "ERC20PrimaryAssetModule".
 */
contract Constructor_ERC20PrimaryAssetModule_Fuzz_Test is ERC20PrimaryAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        ERC20PrimaryAssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_) public {
        vm.startPrank(users.creatorAddress);
        ERC20PrimaryAssetModuleExtension erc20AssetModule_ = new ERC20PrimaryAssetModuleExtension(registry_);
        vm.stopPrank();

        assertEq(erc20AssetModule_.REGISTRY(), registry_);
        assertEq(erc20AssetModule_.ASSET_TYPE(), 0);
    }
}
