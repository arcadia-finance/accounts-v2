/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

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

    function testFuzz_Revert_AddAsset_PoolNotAllowed(address randomToken) public canReceiveERC721(randomToken) {
        // When :  Calling addAsset()
        // Then : It should revert as the aeroPool has not been added to the registry
        vm.expectRevert(WrappedAerodromeAM.PoolNotAllowed.selector);
        wrappedAerodromeAM.addAsset(address(randomToken));
    }

    function testFuzz_Success_AddAsset(bool stable) public {
        // Given : the aeroPool is allowed in the Registry
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), stable);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // When : Calling addAsset()
        wrappedAerodromeAM.addAsset(address(aeroPool));

        // Then : Asset and gauge info should be updated
        if (address(mockERC20.token1) < address(mockERC20.stable1)) {
            assertEq(wrappedAerodromeAM.token0(address(aeroPool)), address(mockERC20.token1));
            assertEq(wrappedAerodromeAM.token1(address(aeroPool)), address(mockERC20.stable1));
        } else {
            assertEq(wrappedAerodromeAM.token0(address(aeroPool)), address(mockERC20.stable1));
            assertEq(wrappedAerodromeAM.token1(address(aeroPool)), address(mockERC20.token1));
        }
    }
}
