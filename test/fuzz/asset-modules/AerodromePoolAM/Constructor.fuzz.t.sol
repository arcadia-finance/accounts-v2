/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

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

    function testFuzz_success_constructor(address aerodromeFactory) public {
        AerodromePoolAMExtension assetModule =
            new AerodromePoolAMExtension(address(registryExtension), aerodromeFactory);

        assertEq(address(assetModule.AERO_FACTORY()), aerodromeFactory);
        assertEq(assetModule.ASSET_TYPE(), 1);
        assertEq(assetModule.REGISTRY(), address(registryExtension));
    }
}
