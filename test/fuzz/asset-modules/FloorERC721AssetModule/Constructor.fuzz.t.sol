/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FloorERC721AssetModule_Fuzz_Test } from "./_FloorERC721AssetModule.fuzz.t.sol";

import { FloorERC721AssetModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "FloorERC721AssetModule".
 */
contract Constructor_FloorERC721AssetModule_Fuzz_Test is FloorERC721AssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721AssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_) public {
        vm.startPrank(users.creatorAddress);
        FloorERC721AssetModuleExtension erc721AssetModule_ = new FloorERC721AssetModuleExtension(registry_);
        vm.stopPrank();

        assertEq(erc721AssetModule_.REGISTRY(), registry_);
        assertEq(erc721AssetModule_.ASSET_TYPE(), 1);
        assertTrue(erc721AssetModule_.getPrimaryFlag());
    }
}
