/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";
import { WrappedMetadex03AM_Fuzz_Test } from "./_WrappedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "addAsset" function of contract "WrappedMetadex03AM".
 */
contract AddAsset_WrappedMetadex03AM_Fuzz_Test is WrappedMetadex03AM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        WrappedMetadex03AM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_addAsset_PoolNotAllowed(address randomToken) public canReceiveERC721(randomToken) {
        // Given: The random token is not added to the Registry.

        // When: The random token is added as a pool.
        // Then: It reverts.
        vm.expectRevert(WrappedAerodromeAM.PoolNotAllowed.selector);
        wrappedMetadex03AM.addAsset(address(randomToken));
    }

    function testFuzz_Success_addAsset(bool stable) public {
        // Given: A pool that is allowed in the Registry.
        metadex03Pool = createPoolMetadex03(address(mockERC20.token1), address(mockERC20.stable1), stable);
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(metadex03Pool));

        // When: The pool is added as an asset.
        wrappedMetadex03AM.addAsset(address(metadex03Pool));

        // Then: Both underlying tokens are stored in sorted order.
        if (address(mockERC20.token1) < address(mockERC20.stable1)) {
            assertEq(wrappedMetadex03AM.token0(address(metadex03Pool)), address(mockERC20.token1));
            assertEq(wrappedMetadex03AM.token1(address(metadex03Pool)), address(mockERC20.stable1));
        } else {
            assertEq(wrappedMetadex03AM.token0(address(metadex03Pool)), address(mockERC20.stable1));
            assertEq(wrappedMetadex03AM.token1(address(metadex03Pool)), address(mockERC20.token1));
        }
    }
}
