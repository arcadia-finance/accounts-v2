/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "WrappedAerodromeAM".
 */
contract Constructor_WrappedAerodromeAM_Fuzz_Test is WrappedAerodromeAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        WrappedAerodromeAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_) public {
        vm.prank(users.creatorAddress);
        WrappedAerodromeAM assetModule_ = new WrappedAerodromeAM(registry_);

        assertEq(assetModule_.REGISTRY(), registry_);
        assertEq(assetModule_.name(), "Arcadia Wrapped Aerodrome Positions");
        assertEq(assetModule_.symbol(), "aWAEROP");
        assertEq(assetModule_.ASSET_TYPE(), 2);
    }
}
