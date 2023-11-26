/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractDerivedAssetModule_Fuzz_Test } from "./_AbstractDerivedAssetModule.fuzz.t.sol";

import { DerivedAssetModuleMock } from "../../../utils/mocks/DerivedAssetModuleMock.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "AbstractDerivedAssetModule".
 */
contract Constructor_AbstractDerivedAssetModule_Fuzz_Test is AbstractDerivedAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedAssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_, uint256 assetType_) public {
        vm.startPrank(users.creatorAddress);
        DerivedAssetModuleMock assetModule_ = new DerivedAssetModuleMock(registry_, assetType_);
        vm.stopPrank();

        assertEq(assetModule_.REGISTRY(), registry_);
        assertEq(assetModule_.ASSET_TYPE(), assetType_);
    }
}
