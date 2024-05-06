/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { Pool } from "../../../utils/fixtures/aerodrome/AeroPoolFixture.f.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

/**
 * @notice Fuzz tests for the function "feesOf" of contract "WrappedAerodromeAM".
 */
contract FeesOf_WrappedAerodromeAM_Fuzz_Test is WrappedAerodromeAM_Fuzz_Test {
    using FixedPointMathLib for uint256;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        WrappedAerodromeAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_feesOf(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 positionId,
        uint256 fee0,
        uint256 fee1,
        bool stable
    ) public {
        // Given : Valid pool
        pool = Pool(poolFactory.createPool(address(asset0), address(asset1), stable));

        // Given : Valid state
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);

        // And : Account has a non-zero balance
        vm.assume(positionState.amountWrapped > 0);

        // And: State is persisted.
        setAMState(pool, positionId, poolState, positionState);
        pool.setClaimables(address(wrappedAerodromeAM), fee0, fee1);

        // When : Calling feesOf()
        (uint256 fee0_, uint256 fee1_) = wrappedAerodromeAM.feesOf(positionId);

        // Then : It should return the correct value
        uint128 fee0PerLiquidity;
        uint128 fee1PerLiquidity;
        unchecked {
            fee0PerLiquidity = poolState.fee0PerLiquidity + uint128(fee0.mulDivDown(1e18, poolState.totalWrapped));
            fee1PerLiquidity = poolState.fee1PerLiquidity + uint128(fee1.mulDivDown(1e18, poolState.totalWrapped));
        }
        uint128 deltaFee0PerLiquidity;
        uint128 deltaFee1PerLiquidity;
        unchecked {
            deltaFee0PerLiquidity = fee0PerLiquidity - positionState.fee0PerLiquidity;
            deltaFee1PerLiquidity = fee1PerLiquidity - positionState.fee1PerLiquidity;
        }
        uint256 deltaFee0 = uint256(positionState.amountWrapped).mulDivDown(deltaFee0PerLiquidity, 1e18);
        uint256 deltaFee1 = uint256(positionState.amountWrapped).mulDivDown(deltaFee1PerLiquidity, 1e18);

        assertEq(fee0_, positionState.fee0 + deltaFee0);
        assertEq(fee1_, positionState.fee1 + deltaFee1);
    }
}
