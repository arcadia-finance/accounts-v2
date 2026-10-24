/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { WrappedMetadex03AM } from "../../../../src/asset-modules/Metadex03/WrappedMetadex03AM.sol";
import { WrappedMetadex03AM_Fuzz_Test } from "./_WrappedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "WrappedMetadex03AM".
 */
contract Constructor_WrappedMetadex03AM_Fuzz_Test is WrappedMetadex03AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        WrappedMetadex03AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_constructor(address registry_) public {
        // Given: The owner is the deployer.
        vm.prank(users.owner);

        // When: A new Asset Module is deployed.
        WrappedMetadex03AM assetModule_ = new WrappedMetadex03AM(users.owner, registry_);

        // Then: The immutables and the ERC721 metadata are set.
        assertEq(assetModule_.REGISTRY(), registry_);
        assertEq(assetModule_.name(), "Arcadia Wrapped Metadex03 Positions");
        assertEq(assetModule_.symbol(), "aWMDEXP");
        assertEq(assetModule_.ASSET_TYPE(), 2);
    }
}
