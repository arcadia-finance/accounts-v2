/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractPrimaryAM_Fuzz_Test } from "./_AbstractPrimaryAM.fuzz.t.sol";

import { PrimaryAMMock } from "../../../utils/mocks/asset-modules/PrimaryAMMock.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "AbstractPrimaryAM".
 */
contract Constructor_AbstractPrimaryAM_Fuzz_Test is AbstractPrimaryAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_, uint256 assetType_) public {
        vm.startPrank(users.creatorAddress);
        PrimaryAMMock assetModule_ = new PrimaryAMMock(registry_, assetType_);
        vm.stopPrank();

        assertEq(assetModule_.REGISTRY(), registry_);
        assertEq(assetModule_.ASSET_TYPE(), assetType_);
    }
}
