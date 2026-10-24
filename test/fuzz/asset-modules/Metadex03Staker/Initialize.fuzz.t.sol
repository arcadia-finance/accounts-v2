/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Metadex03Staker } from "../../../../src/asset-modules/Metadex03/Metadex03Staker.sol";
import { Metadex03Staker_Fuzz_Test } from "./_Metadex03Staker.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "initialize" of contract "Metadex03Staker".
 */
contract Initialize_Metadex03Staker_Fuzz_Test is Metadex03Staker_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Metadex03Staker_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_initialize_OnlyAssetModule(
        address assetModule,
        address caller,
        address gauge,
        address asset
    ) public {
        // Given: A staker deployed by the Asset Module.
        vm.prank(assetModule);
        Metadex03Staker staker = new Metadex03Staker();

        // And: The caller is not the Asset Module.
        vm.assume(caller != assetModule);

        // When: The caller initializes the staker.
        // Then: It reverts.
        vm.prank(caller);
        vm.expectRevert(Metadex03Staker.OnlyAssetModule.selector);
        staker.initialize(gauge, asset);
    }

    function testFuzz_Success_initialize(address assetModule) public {
        // Given: A staker deployed by a non-zero Asset Module.
        vm.assume(assetModule != address(0));
        vm.prank(assetModule);
        Metadex03Staker staker = new Metadex03Staker();

        // When: The Asset Module initializes the staker for the gauge of the pool.
        vm.prank(assetModule);
        staker.initialize(address(metadex03Gauge), address(metadex03Pool));

        // Then: The Asset Module can withdraw and claim for the staker.
        assertTrue(metadex03Gauge.isApprovedForAll(address(staker), assetModule));
        assertTrue(metadex03Gauge.approvedForClaim(address(staker), assetModule));

        // And: The gauge can pull any amount of LP from the staker.
        assertEq(metadex03Pool.allowance(address(staker), address(metadex03Gauge)), type(uint256).max);
    }
}
