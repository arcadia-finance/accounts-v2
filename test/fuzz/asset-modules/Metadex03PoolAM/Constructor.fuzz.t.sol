/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Metadex03PoolAM_Fuzz_Test } from "./_Metadex03PoolAM.fuzz.t.sol";
import { Metadex03PoolAMExtension } from "../../../utils/extensions/Metadex03PoolAMExtension.sol";
import { Unused } from "../../../../src/libraries/Unused.sol";

/**
 * @notice Fuzz tests for the constructor of contract "Metadex03PoolAM".
 */
contract Constructor_Metadex03PoolAM_Fuzz_Test is Metadex03PoolAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Metadex03PoolAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_constructor(
        address owner_,
        address registry_,
        address stablePoolFactory_,
        address volatilePoolFactory_
    ) public {
        // Given:

        // When: The Asset Module is deployed.
        Metadex03PoolAMExtension assetModule =
            new Metadex03PoolAMExtension(owner_, registry_, stablePoolFactory_, volatilePoolFactory_);

        // Then: The constructor arguments are stored.
        assertEq(assetModule.owner(), owner_);
        assertEq(assetModule.REGISTRY(), registry_);
        assertEq(address(assetModule.STABLE_POOL_FACTORY()), stablePoolFactory_);
        assertEq(address(assetModule.VOLATILE_POOL_FACTORY()), volatilePoolFactory_);

        // And: The asset type is the one of an ERC20.
        assertEq(assetModule.ASSET_TYPE(), 1);

        // And: The inherited AERO_FACTORY is never read, so it holds the unused sentinel.
        assertEq(address(assetModule.AERO_FACTORY()), Unused.IMMUTABLE);
    }
}
