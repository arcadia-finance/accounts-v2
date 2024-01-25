/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { NSStargateAssetModule_Fuzz_Test } from "./_NSStargateAssetModule.fuzz.t.sol";

import { NSStargateAssetModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the constructor of contract "NSStargateAssetModule".
 */
contract Constructor_NSStargateAssetModule_Fuzz_Test is NSStargateAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        NSStargateAssetModule_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_success_constructor(address stargateFactory) public {
        NSStargateAssetModuleExtension assetModule =
            new NSStargateAssetModuleExtension(address(registryExtension), stargateFactory);

        assertEq(address(assetModule.SG_FACTORY()), stargateFactory);
        assertEq(assetModule.ASSET_TYPE(), 0);
        assertEq(assetModule.REGISTRY(), address(registryExtension));
    }
}
