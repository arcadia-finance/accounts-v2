/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";
import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

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
        // Given: A pool with a valid wrapped state.
        aeroPool = createPoolAerodrome(address(asset0), address(asset1), stable);
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);

        // And: That state is persisted and the pool holds claimable fees.
        setAMState(aeroPool, positionId, poolState, positionState);
        aeroPool.setClaimables(address(wrappedAerodromeAM), fee0, fee1);

        // When: The fees of the position are read.
        (uint256 fee0_, uint256 fee1_) = wrappedAerodromeAM.feesOf(positionId);

        // Then: The fee balance grows with the share of the position in the accrued fees.
        uint128 fee0PerLiquidity;
        uint128 fee1PerLiquidity;
        unchecked {
            // forge-lint: disable-next-item(unsafe-typecast)
            fee0PerLiquidity = poolState.fee0PerLiquidity + uint128(fee0.mulDivDown(1e18, poolState.totalWrapped));
            // forge-lint: disable-next-item(unsafe-typecast)
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
