/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";
import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "addAsset" function of contract "WrappedAerodromeAM".
 */
contract AddAsset_WrappedAerodromeAM_Fuzz_Test is WrappedAerodromeAM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        WrappedAerodromeAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_addAsset_PoolNotAllowed(address randomToken) public canReceiveERC721(randomToken) {
        // Given: The random token is not added to the Registry.

        // When: The random token is added as a pool.
        // Then: It reverts.
        vm.expectRevert(WrappedAerodromeAM.PoolNotAllowed.selector);
        wrappedAerodromeAM.addAsset(address(randomToken));
    }

    function testFuzz_Success_addAsset(bool stable) public {
        // Given: A pool that is allowed in the Registry.
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), stable);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // When: The pool is added as an asset.
        wrappedAerodromeAM.addAsset(address(aeroPool));

        // Then: Both underlying tokens are stored in sorted order.
        if (address(mockERC20.token1) < address(mockERC20.stable1)) {
            assertEq(wrappedAerodromeAM.token0(address(aeroPool)), address(mockERC20.token1));
            assertEq(wrappedAerodromeAM.token1(address(aeroPool)), address(mockERC20.stable1));
        } else {
            assertEq(wrappedAerodromeAM.token0(address(aeroPool)), address(mockERC20.stable1));
            assertEq(wrappedAerodromeAM.token1(address(aeroPool)), address(mockERC20.token1));
        }
    }
}
