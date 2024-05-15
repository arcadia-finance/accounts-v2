/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractWrappedAM_Fuzz_Test } from "./_AbstractWrappedAM.fuzz.t.sol";

import { WrappedAMMock } from "../../../utils/mocks/asset-modules/WrappedAMMock.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "WrappedAM".
 */
contract Constructor_WrappedAM_Fuzz_Test is AbstractWrappedAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractWrappedAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_, string memory name_, string memory symbol_) public {
        vm.startPrank(users.creatorAddress);
        WrappedAMMock assetModule_ = new WrappedAMMock(registry_, name_, symbol_);
        vm.stopPrank();

        assertEq(assetModule_.REGISTRY(), registry_);
        assertEq(assetModule_.name(), name_);
        assertEq(assetModule_.symbol(), symbol_);
        assertEq(assetModule_.ASSET_TYPE(), 2);
    }
}
