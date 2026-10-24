/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";
import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

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

    function testFuzz_Success_constructor(address registry_) public {
        // Given: The owner is the deployer.
        vm.prank(users.owner);

        // When: A new Asset Module is deployed.
        WrappedAerodromeAM assetModule_ = new WrappedAerodromeAM(users.owner, registry_);

        // Then: The immutables and the ERC721 metadata are set.
        assertEq(assetModule_.REGISTRY(), registry_);
        assertEq(assetModule_.name(), "Arcadia Wrapped Aerodrome Positions");
        assertEq(assetModule_.symbol(), "aWAEROP");
        assertEq(assetModule_.ASSET_TYPE(), 2);
    }
}
