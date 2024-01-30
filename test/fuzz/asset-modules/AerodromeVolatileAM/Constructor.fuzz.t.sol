/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AerodromeVolatileAM_Fuzz_Test } from "./_AerodromeVolatileAM.fuzz.t.sol";

import { AerodromeVolatileAMExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the constructor of contract "AerodromeVolatileAM".
 */
contract Constructor_AerodromeVolatileAM_Fuzz_Test is AerodromeVolatileAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromeVolatileAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_success_constructor(address aerodromeFactory) public {
        AerodromeVolatileAMExtension assetModule =
            new AerodromeVolatileAMExtension(address(registryExtension), aerodromeFactory);

        assertEq(address(assetModule.AERO_FACTORY()), aerodromeFactory);
        assertEq(assetModule.ASSET_TYPE(), 0);
        assertEq(assetModule.REGISTRY(), address(registryExtension));
    }
}
