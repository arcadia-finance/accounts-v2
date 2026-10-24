/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AerodromePoolAM_Fuzz_Test } from "./_AerodromePoolAM.fuzz.t.sol";
import { AerodromePoolAMExtension } from "../../../utils/extensions/AerodromePoolAMExtension.sol";

/**
 * @notice Fuzz tests for the constructor of contract "AerodromePoolAM".
 */
contract Constructor_AerodromePoolAM_Fuzz_Test is AerodromePoolAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromePoolAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_constructor(address owner_, address registry_, address aerodromeFactory) public {
        // Given:

        // When: The Asset Module is deployed.
        AerodromePoolAMExtension assetModule = new AerodromePoolAMExtension(owner_, registry_, aerodromeFactory);

        // Then: The constructor arguments are stored.
        assertEq(assetModule.owner(), owner_);
        assertEq(assetModule.REGISTRY(), registry_);
        assertEq(address(assetModule.AERO_FACTORY()), aerodromeFactory);

        // And: The asset type is the one of an ERC20.
        assertEq(assetModule.ASSET_TYPE(), 1);
    }
}
