/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAssetModule_Fuzz_Test, StargateAssetModule } from "./_StargateAssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the constructor of contract "StargateAssetModule".
 */
contract Constructor_StargateAssetModule_Fuzz_Test is StargateAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StargateAssetModule_Fuzz_Test.setUp();
    }

    function testFuzz_success_constructor(address lpStakingContract, address registry) public {
        StargateAssetModule assetModule = new StargateAssetModule(registry, lpStakingContract);

        assertEq(address(assetModule.stargateLpStaking()), lpStakingContract);
        assertEq(assetModule.ASSET_TYPE(), 2);
        assertEq(assetModule.REGISTRY(), registry);
    }
}
