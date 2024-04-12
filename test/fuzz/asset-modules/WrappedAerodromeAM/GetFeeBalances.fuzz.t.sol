/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { Pool } from "../../../utils/fixtures/aerodrome/AeroPoolFixture.f.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

/**
 * @notice Fuzz tests for the function "_getFeeBalances" of contract "WrappedAerodromeAM".
 */
contract GetFeeBalances_WrappedAerodromeAM_Fuzz_Test is WrappedAerodromeAM_Fuzz_Test {
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

    function testFuzz_Revert_getFeeBalances_NonZeroTotalWrapped_OverflowDeltaFee0PerLiquidity_MulDivDown(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public {
        // Given: more than 1 gwei is staked.
        poolState.totalWrapped = uint128(bound(poolState.totalWrapped, 1, type(uint128).max));

        // And: deltaFee0PerLiquidity mulDivDown overflows.
        fee0 = bound(fee0, type(uint256).max / 1e18 + 1, type(uint256).max);

        // When: Calling _getFeeBalances().
        // Then: transaction reverts.
        vm.expectRevert(bytes(""));
        wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);
    }

    function testFuzz_Revert_getFeeBalances_NonZeroTotalWrapped_OverflowDeltaFee1PerLiquidity_MulDivDown(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public {
        // Given: more than 1 gwei is staked.
        poolState.totalWrapped = uint128(bound(poolState.totalWrapped, 1, type(uint128).max));

        // And: deltaFee0PerLiquidity does not overflow.
        fee0 = bound(fee0, 0, type(uint256).max / 1e18);

        // And: deltaFee1PerLiquidity overflows
        fee1 = bound(fee1, type(uint256).max / 1e18 + 1, type(uint256).max);

        // When: Calling _getFeeBalances().
        // Then: transaction reverts.
        vm.expectRevert(bytes(""));
        wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);
    }

    function testFuzz_Revert_getFeeBalances_NonZeroTotalWrapped_OverflowDeltaFee0PerLiquidity_SafeCast(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public {
        // Given: more than 1 gwei is staked.
        poolState.totalWrapped = uint128(bound(poolState.totalWrapped, 1, type(uint128).max - 1));

        // And: deltaFee0PerLiquidity is bigger as type(uint128).max (overflow safeCastTo128).
        uint256 lowerBound = (poolState.totalWrapped < 1e18)
            ? uint256(type(uint128).max).mulDivUp(poolState.totalWrapped, 1e18)
            : uint256(type(uint128).max) * poolState.totalWrapped / 1e18 + poolState.totalWrapped;
        fee0 = bound(fee0, lowerBound, type(uint256).max);

        // And: deltaFee1PerLiquidity does not overflow.
        fee1 = bound(fee1, 0, type(uint256).max / 1e18);

        // When: Calling _getFeeBalances().
        // Then: transaction reverts.
        vm.expectRevert(bytes(""));
        wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);
    }

    function testFuzz_Revert_getFeeBalances_NonZeroTotalWrapped_OverflowDeltaFee1PerLiquidity_SafeCast(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public {
        // Given: more than 1 gwei is staked.
        poolState.totalWrapped = uint128(bound(poolState.totalWrapped, 1, type(uint128).max - 1));

        // And: deltaFee0PerLiquidity is smaller or equal as type(uint128).max (no overflow safeCastTo128).
        fee0 = bound(fee0, 0, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);

        // And: deltaFee1PerLiquidity is bigger as type(uint128).max (overflow safeCastTo128).
        uint256 lowerBound = (poolState.totalWrapped < 1e18)
            ? uint256(type(uint128).max).mulDivUp(poolState.totalWrapped, 1e18)
            : uint256(type(uint128).max) * poolState.totalWrapped / 1e18 + poolState.totalWrapped;
        fee1 = bound(fee1, lowerBound, type(uint256).max);

        // When: Calling _getFeeBalances().
        // Then: transaction reverts.
        vm.expectRevert(bytes(""));
        wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);
    }

    function testFuzz_Revert_getFeeBalances_NonZeroTotalWrapped_OverflowDeltaFee0(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public {
        // Given: more than 1 gwei is staked.
        poolState.totalWrapped = uint128(bound(poolState.totalWrapped, 1e18 + 1, type(uint128).max));

        // And: totalWrapped should be >= to amountWrappedForPosition (invariant).
        positionState.amountWrapped = uint128(bound(positionState.amountWrapped, 1e18 + 1, poolState.totalWrapped));

        // And: deltaFeesPerLiquidity is smaller or equal as type(uint128).max (no overflow safeCastTo128).
        fee0 = bound(fee0, 1, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);
        fee1 = bound(fee1, 1, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);

        // Calculate the new fee0PerLiquidity.
        uint256 deltaFee0PerLiquidity = fee0 * 1e18 / poolState.totalWrapped;
        uint128 currentFee0PerLiquidity;
        unchecked {
            currentFee0PerLiquidity = poolState.fee0PerLiquidity + uint128(deltaFee0PerLiquidity);
        }

        // And: deltaFee0 of the position is bigger than type(uint128).max (overflow).
        unchecked {
            deltaFee0PerLiquidity = currentFee0PerLiquidity - positionState.fee0PerLiquidity;
        }
        deltaFee0PerLiquidity = bound(
            deltaFee0PerLiquidity,
            type(uint128).max * uint256(1e18 + 1) / positionState.amountWrapped,
            type(uint128).max
        );
        unchecked {
            positionState.fee0PerLiquidity = currentFee0PerLiquidity - uint128(deltaFee0PerLiquidity);
        }

        vm.expectRevert(bytes(""));
        wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);
    }

    function testFuzz_Revert_getFeeBalances_NonZeroTotalWrapped_OverflowDeltaFee1(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public {
        // Given: more than 1 gwei is staked.
        poolState.totalWrapped = uint128(bound(poolState.totalWrapped, 1e18 + 1, type(uint128).max));

        // And: totalWrapped should be >= to amountWrappedForPosition (invariant).
        positionState.amountWrapped = uint128(bound(positionState.amountWrapped, 1e18 + 1, poolState.totalWrapped));

        // And: deltaFeesPerLiquidity is smaller or equal as type(uint128).max (no overflow safeCastTo128).
        fee0 = bound(fee0, 1, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);
        fee1 = bound(fee1, 1, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);

        // Calculate the new fee0PerLiquidity.
        uint256 deltaFee0PerLiquidity = fee0 * 1e18 / poolState.totalWrapped;
        uint128 currentFee0PerLiquidity;
        unchecked {
            currentFee0PerLiquidity = poolState.fee0PerLiquidity + uint128(deltaFee0PerLiquidity);
        }
        // And: New fee0 does not overflow.
        // -> fee0PerLiquidity of the position is smaller or equal to type(uint128).max (overflow).
        // -> deltaFee0PerLiquidity * positionState.amountWrapped / 1e18 <= type(uint128).max;
        unchecked {
            deltaFee0PerLiquidity = currentFee0PerLiquidity - positionState.fee0PerLiquidity;
        }
        deltaFee0PerLiquidity =
            bound(deltaFee0PerLiquidity, 0, type(uint128).max * uint256(1e18) / positionState.amountWrapped);
        unchecked {
            positionState.fee0PerLiquidity = currentFee0PerLiquidity - uint128(deltaFee0PerLiquidity);
        }
        // And: Previously earned fee0 for Account + new fee0 does not overflow.
        // -> fee0 + deltaFee0 <= type(uint128).max;
        uint256 deltaFee0 = deltaFee0PerLiquidity * uint256(positionState.amountWrapped) / 1e18;
        positionState.fee0 = uint128(bound(positionState.fee0, 0, type(uint128).max - deltaFee0));

        // Calculate the new fee1PerLiquidity.
        uint256 deltaFee1PerLiquidity = fee1 * 1e18 / poolState.totalWrapped;
        uint128 currentFee1PerLiquidity;
        unchecked {
            currentFee1PerLiquidity = poolState.fee1PerLiquidity + uint128(deltaFee1PerLiquidity);
        }

        // And: deltaFee1 of the position is bigger than type(uint128).max (overflow).
        unchecked {
            deltaFee1PerLiquidity = currentFee1PerLiquidity - positionState.fee1PerLiquidity;
        }
        deltaFee1PerLiquidity = bound(
            deltaFee1PerLiquidity,
            type(uint128).max * uint256(1e18 + 1) / positionState.amountWrapped,
            type(uint128).max
        );
        unchecked {
            positionState.fee1PerLiquidity = currentFee1PerLiquidity - uint128(deltaFee1PerLiquidity);
        }

        vm.expectRevert(bytes(""));
        wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);
    }

    function testFuzz_Revert_getFeeBalances_NonZeroTotalWrapped_OverflowFee0(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public {
        // Given: more than 1 gwei is staked.
        poolState.totalWrapped = uint128(bound(poolState.totalWrapped, 1, type(uint128).max));

        // And: totalWrapped should be >= to amountWrappedForPosition (invariant).
        positionState.amountWrapped = uint128(bound(positionState.amountWrapped, 1, poolState.totalWrapped));

        // And: deltaFeesPerLiquidity is smaller or equal as type(uint128).max (no overflow safeCastTo128).
        fee0 = bound(fee0, 1, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);
        fee1 = bound(fee1, 1, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);

        // Calculate the new fee0PerLiquidity.
        uint256 deltaFee0PerLiquidity = fee0 * 1e18 / poolState.totalWrapped;
        uint128 currentFee0PerLiquidity;
        unchecked {
            currentFee0PerLiquidity = poolState.fee0PerLiquidity + uint128(deltaFee0PerLiquidity);
        }

        // And: previously earned rewards for Account + new rewards overflow.
        // -> deltaFee0 must be greater as 1
        unchecked {
            deltaFee0PerLiquidity = currentFee0PerLiquidity - positionState.fee0PerLiquidity;
        }
        deltaFee0PerLiquidity = bound(deltaFee0PerLiquidity, 1e18 / positionState.amountWrapped + 1, type(uint128).max);
        unchecked {
            positionState.fee0PerLiquidity = currentFee0PerLiquidity - uint128(deltaFee0PerLiquidity);
        }
        uint256 deltaFee0 = deltaFee0PerLiquidity * positionState.amountWrapped / 1e18;
        positionState.fee0 = uint128(
            bound(
                positionState.fee0,
                deltaFee0 > type(uint128).max ? 0 : type(uint128).max - deltaFee0 + 1,
                type(uint128).max
            )
        );

        vm.expectRevert(bytes(""));
        wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);
    }

    function testFuzz_Revert_getFeeBalances_NonZeroTotalWrapped_OverflowFee1(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public {
        // Given: more than 1 gwei is staked.
        poolState.totalWrapped = uint128(bound(poolState.totalWrapped, 1, type(uint128).max));

        // And: totalWrapped should be >= to amountWrappedForPosition (invariant).
        positionState.amountWrapped = uint128(bound(positionState.amountWrapped, 1, poolState.totalWrapped));

        // And: deltaFeesPerLiquidity is smaller or equal as type(uint128).max (no overflow safeCastTo128).
        fee0 = bound(fee0, 1, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);
        fee1 = bound(fee1, 1, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);

        // Calculate the new fee0PerLiquidity.
        uint256 deltaFee0PerLiquidity = fee0 * 1e18 / poolState.totalWrapped;
        uint128 currentFee0PerLiquidity;
        unchecked {
            currentFee0PerLiquidity = poolState.fee0PerLiquidity + uint128(deltaFee0PerLiquidity);
        }
        // And: New fee0 does not overflow.
        // -> fee0PerLiquidity of the position is smaller or equal to type(uint128).max (overflow).
        // -> deltaFee0PerLiquidity * positionState.amountWrapped / 1e18 <= type(uint128).max;
        unchecked {
            deltaFee0PerLiquidity = currentFee0PerLiquidity - positionState.fee0PerLiquidity;
        }
        deltaFee0PerLiquidity =
            bound(deltaFee0PerLiquidity, 0, type(uint128).max * uint256(1e18) / positionState.amountWrapped);
        unchecked {
            positionState.fee0PerLiquidity = currentFee0PerLiquidity - uint128(deltaFee0PerLiquidity);
        }
        // And: Previously earned fee0 for Account + new fee0 does not overflow.
        // -> fee0 + deltaFee0 <= type(uint128).max;
        uint256 deltaFee0 = deltaFee0PerLiquidity * uint256(positionState.amountWrapped) / 1e18;
        positionState.fee0 = uint128(bound(positionState.fee0, 0, type(uint128).max - deltaFee0));

        // Calculate the new fee1PerLiquidity.
        uint256 deltaFee1PerLiquidity = fee1 * 1e18 / poolState.totalWrapped;
        uint128 currentFee1PerLiquidity;
        unchecked {
            currentFee1PerLiquidity = poolState.fee1PerLiquidity + uint128(deltaFee1PerLiquidity);
        }
        // And: previously earned rewards for Account + new rewards overflow.
        // -> deltaFee1 must be greater as 1
        unchecked {
            deltaFee1PerLiquidity = currentFee1PerLiquidity - positionState.fee1PerLiquidity;
        }
        deltaFee1PerLiquidity = bound(deltaFee1PerLiquidity, 1e18 / positionState.amountWrapped + 1, type(uint128).max);
        unchecked {
            positionState.fee1PerLiquidity = currentFee1PerLiquidity - uint128(deltaFee1PerLiquidity);
        }
        uint256 deltaFee1 = deltaFee1PerLiquidity * positionState.amountWrapped / 1e18;
        positionState.fee1 = uint128(
            bound(
                positionState.fee1,
                deltaFee1 > type(uint128).max ? 0 : type(uint128).max - deltaFee1 + 1,
                type(uint128).max
            )
        );

        vm.expectRevert(bytes(""));
        wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);
    }

    function testFuzz_Success_getFeeBalances_ZeroTotalWrapped(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public {
        // Given: totalWrapped is zero.
        poolState.totalWrapped = 0;

        // When : Calling _getFeeBalances().
        (WrappedAerodromeAM.PoolState memory poolState_, WrappedAerodromeAM.PositionState memory positionState_) =
            wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);

        // Then : It should return the correct values
        assertEq(poolState_.fee0PerLiquidity, poolState.fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, poolState.fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, poolState.totalWrapped);

        assertEq(positionState_.fee0PerLiquidity, poolState.fee0PerLiquidity);
        assertEq(positionState_.fee1PerLiquidity, poolState.fee1PerLiquidity);
        assertEq(positionState_.fee0, positionState.fee0);
        assertEq(positionState_.fee1, positionState.fee1);
        assertEq(positionState_.amountWrapped, positionState.amountWrapped);
        assertEq(positionState_.pool, positionState.pool);
    }

    function testFuzz_Success_getFeeBalances_NonZeroTotalWrapped(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public {
        // Given : Valid state
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);

        // When : Calling _getFeeBalances().
        (WrappedAerodromeAM.PoolState memory poolState_, WrappedAerodromeAM.PositionState memory positionState_) =
            wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);

        // Then : It should return the correct values
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

        // Then : It should return the correct values
        assertEq(poolState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, poolState.totalWrapped);

        assertEq(positionState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(positionState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(positionState_.fee0, positionState.fee0 + deltaFee0);
        assertEq(positionState_.fee1, positionState.fee1 + deltaFee1);
        assertEq(positionState_.amountWrapped, positionState.amountWrapped);
        assertEq(positionState_.pool, positionState.pool);
    }
}
