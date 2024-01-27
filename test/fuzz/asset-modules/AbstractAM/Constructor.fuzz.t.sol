/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractAM_Fuzz_Test } from "./_AbstractAM.fuzz.t.sol";

import { AssetModuleMock } from "../../../utils/mocks/asset-modules/AssetModuleMock.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "AbstractAM".
 */
contract Constructor_AbstractAM_Fuzz_Test is AbstractAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_, uint256 assetType_) public {
        vm.startPrank(users.creatorAddress);
        AssetModuleMock assetModule_ = new AssetModuleMock(registry_, assetType_);
        vm.stopPrank();

        assertEq(assetModule_.REGISTRY(), registry_);
        assertEq(assetModule_.ASSET_TYPE(), assetType_);
    }
}
