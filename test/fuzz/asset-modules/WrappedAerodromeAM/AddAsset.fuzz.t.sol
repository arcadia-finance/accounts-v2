/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { Pool } from "../../../utils/fixtures/aerodrome/AeroPoolFixture.f.sol";
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

    function testFuzz_Revert_AddAsset_PoolNotAllowed(address randomToken)
        public
        notTestContracts(randomToken)
        notTestContracts2(randomToken)
    {
        // When :  Calling addAsset()
        // Then : It should revert as the pool has not been added to the registry
        vm.expectRevert(WrappedAerodromeAM.PoolNotAllowed.selector);
        wrappedAerodromeAM.addAsset(address(randomToken));
    }

    function testFuzz_Success_AddAsset(bool stable) public {
        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), stable);

        // When : Calling addAsset()
        wrappedAerodromeAM.addAsset(address(pool));

        // Then : Asset and gauge info should be updated
        assertEq(wrappedAerodromeAM.token0(address(pool)), address(mockERC20.token1));
        assertEq(wrappedAerodromeAM.token1(address(pool)), address(mockERC20.stable1));
    }
}
