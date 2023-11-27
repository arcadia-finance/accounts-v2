/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractPrimaryAssetModule_Fuzz_Test } from "./_AbstractPrimaryAssetModule.fuzz.t.sol";

import { PrimaryAssetModuleMock } from "../../../utils/mocks/PrimaryAssetModuleMock.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "AbstractPrimaryAssetModule".
 */
contract Constructor_AbstractPrimaryAssetModule_Fuzz_Test is AbstractPrimaryAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryAssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_, uint256 assetType_) public {
        vm.startPrank(users.creatorAddress);
        PrimaryAssetModuleMock assetModule_ = new PrimaryAssetModuleMock(registry_, assetType_);
        vm.stopPrank();

        assertEq(assetModule_.REGISTRY(), registry_);
        assertEq(assetModule_.ASSET_TYPE(), assetType_);
    }
}
