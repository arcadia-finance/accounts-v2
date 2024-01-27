/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAM_Fuzz_Test } from "./_StargateAM.fuzz.t.sol";

import { StargateAMExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the constructor of contract "StargateAM".
 */
contract Constructor_StargateAM_Fuzz_Test is StargateAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StargateAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_success_constructor(address stargateFactory) public {
        StargateAMExtension assetModule = new StargateAMExtension(address(registryExtension), stargateFactory);

        assertEq(address(assetModule.SG_FACTORY()), stargateFactory);
        assertEq(assetModule.ASSET_TYPE(), 0);
        assertEq(assetModule.REGISTRY(), address(registryExtension));
    }
}
