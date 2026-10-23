/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";
import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getFeeBalances" of contract "WrappedAerodromeAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
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
        // Given: A non-zero amount of liquidity is wrapped.
        vm.assume(poolState.totalWrapped != 0);

        // And: The accrued fee0 exceeds what the fee0 growth per unit of liquidity can represent.
        fee0 = bound(fee0, type(uint256).max / 1e18 + 1, type(uint256).max);

        // When: The fee balances are calculated.
        // Then: It reverts on the overflow of the fee0 growth per unit of liquidity.
        vm.expectRevert(bytes(""));
        wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);
    }

    function testFuzz_Revert_getFeeBalances_NonZeroTotalWrapped_OverflowDeltaFee1PerLiquidity_MulDivDown(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public {
        // Given: A non-zero amount of liquidity is wrapped.
        vm.assume(poolState.totalWrapped != 0);

        // And: The accrued fee0 stays within what the fee0 growth per unit of liquidity can represent.
        fee0 = bound(fee0, 0, type(uint256).max / 1e18);

        // And: The accrued fee1 exceeds what the fee1 growth per unit of liquidity can represent.
        fee1 = bound(fee1, type(uint256).max / 1e18 + 1, type(uint256).max);

        // When: The fee balances are calculated.
        // Then: It reverts on the overflow of the fee1 growth per unit of liquidity.
        vm.expectRevert(bytes(""));
        wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);
    }

    function testFuzz_Revert_getFeeBalances_NonZeroTotalWrapped_OverflowDeltaFee0(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public {
        // Given: A wrapped total above 1e18.
        poolState.totalWrapped = uint128(bound(poolState.totalWrapped, 1e18 + 1, type(uint128).max));

        // And: The position wraps above 1e18 and at most the total wrapped amount.
        positionState.amountWrapped = uint128(bound(positionState.amountWrapped, 1e18 + 1, poolState.totalWrapped));

        // And: The accrued pool fees keep both fee accumulators within uint128.
        fee0 = bound(fee0, 1, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);
        fee1 = bound(fee1, 1, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);

        // And: The pool advanced its fee0 accumulator by the accrued fee0.
        uint256 deltaFee0PerLiquidity = fee0 * 1e18 / poolState.totalWrapped;
        uint128 currentFee0PerLiquidity;
        unchecked {
            currentFee0PerLiquidity = poolState.fee0PerLiquidity + uint128(deltaFee0PerLiquidity);
        }

        // And: The fee0 newly earned by the position exceeds uint128.
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

        // When: The fee balances are calculated.
        // Then: It reverts on the overflow of the fee0 newly earned by the position.
        vm.expectRevert(bytes(""));
        wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);
    }

    function testFuzz_Revert_getFeeBalances_NonZeroTotalWrapped_OverflowFee0(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public {
        // Given: A non-zero amount of liquidity is wrapped.
        vm.assume(poolState.totalWrapped != 0);

        // And: The position wraps at most the total wrapped amount.
        positionState.amountWrapped = uint128(bound(positionState.amountWrapped, 1, poolState.totalWrapped));

        // And: The accrued pool fees keep both fee accumulators within uint128.
        fee0 = bound(fee0, 1, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);
        fee1 = bound(fee1, 1, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);

        // And: The pool advanced its fee0 accumulator by the accrued fee0.
        uint256 deltaFee0PerLiquidity = fee0 * 1e18 / poolState.totalWrapped;
        uint128 currentFee0PerLiquidity;
        unchecked {
            currentFee0PerLiquidity = poolState.fee0PerLiquidity + uint128(deltaFee0PerLiquidity);
        }

        // And: The position newly earns at least 1 wei of fee0.
        unchecked {
            deltaFee0PerLiquidity = currentFee0PerLiquidity - positionState.fee0PerLiquidity;
        }
        deltaFee0PerLiquidity = bound(deltaFee0PerLiquidity, 1e18 / positionState.amountWrapped + 1, type(uint128).max);
        unchecked {
            positionState.fee0PerLiquidity = currentFee0PerLiquidity - uint128(deltaFee0PerLiquidity);
        }

        // And: The fee0 balance of the position plus the newly earned fee0 exceeds uint128.
        uint256 deltaFee0 = deltaFee0PerLiquidity * positionState.amountWrapped / 1e18;
        positionState.fee0 = uint128(
            bound(
                positionState.fee0,
                deltaFee0 > type(uint128).max ? 0 : type(uint128).max - deltaFee0 + 1,
                type(uint128).max
            )
        );

        // When: The fee balances are calculated.
        // Then: It reverts on the overflow of the fee0 balance of the position.
        vm.expectRevert(bytes(""));
        wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);
    }

    function testFuzz_Revert_getFeeBalances_NonZeroTotalWrapped_OverflowDeltaFee1(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public {
        // Given: A wrapped total above 1e18.
        poolState.totalWrapped = uint128(bound(poolState.totalWrapped, 1e18 + 1, type(uint128).max));

        // And: The position wraps above 1e18 and at most the total wrapped amount.
        positionState.amountWrapped = uint128(bound(positionState.amountWrapped, 1e18 + 1, poolState.totalWrapped));

        // And: The accrued pool fees keep both fee accumulators within uint128.
        fee0 = bound(fee0, 1, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);
        fee1 = bound(fee1, 1, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);

        // And: The pool advanced its fee0 accumulator by the accrued fee0.
        uint256 deltaFee0PerLiquidity = fee0 * 1e18 / poolState.totalWrapped;
        uint128 currentFee0PerLiquidity;
        unchecked {
            currentFee0PerLiquidity = poolState.fee0PerLiquidity + uint128(deltaFee0PerLiquidity);
        }

        // And: The fee0 newly earned by the position stays within uint128.
        unchecked {
            deltaFee0PerLiquidity = currentFee0PerLiquidity - positionState.fee0PerLiquidity;
        }
        deltaFee0PerLiquidity =
            bound(deltaFee0PerLiquidity, 0, type(uint128).max * uint256(1e18) / positionState.amountWrapped);
        unchecked {
            positionState.fee0PerLiquidity = currentFee0PerLiquidity - uint128(deltaFee0PerLiquidity);
        }

        // And: The fee0 balance of the position plus the newly earned fee0 stays within uint128.
        uint256 deltaFee0 = deltaFee0PerLiquidity * uint256(positionState.amountWrapped) / 1e18;
        positionState.fee0 = uint128(bound(positionState.fee0, 0, type(uint128).max - deltaFee0));

        // And: The pool advanced its fee1 accumulator by the accrued fee1.
        uint256 deltaFee1PerLiquidity = fee1 * 1e18 / poolState.totalWrapped;
        uint128 currentFee1PerLiquidity;
        unchecked {
            currentFee1PerLiquidity = poolState.fee1PerLiquidity + uint128(deltaFee1PerLiquidity);
        }

        // And: The fee1 newly earned by the position exceeds uint128.
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

        // When: The fee balances are calculated.
        // Then: It reverts on the overflow of the fee1 newly earned by the position.
        vm.expectRevert(bytes(""));
        wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);
    }

    function testFuzz_Revert_getFeeBalances_NonZeroTotalWrapped_OverflowFee1(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public {
        // Given: A non-zero amount of liquidity is wrapped.
        vm.assume(poolState.totalWrapped != 0);

        // And: The position wraps at most the total wrapped amount.
        positionState.amountWrapped = uint128(bound(positionState.amountWrapped, 1, poolState.totalWrapped));

        // And: The accrued pool fees keep both fee accumulators within uint128.
        fee0 = bound(fee0, 1, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);
        fee1 = bound(fee1, 1, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);

        // And: The pool advanced its fee0 accumulator by the accrued fee0.
        uint256 deltaFee0PerLiquidity = fee0 * 1e18 / poolState.totalWrapped;
        uint128 currentFee0PerLiquidity;
        unchecked {
            currentFee0PerLiquidity = poolState.fee0PerLiquidity + uint128(deltaFee0PerLiquidity);
        }

        // And: The fee0 newly earned by the position stays within uint128.
        unchecked {
            deltaFee0PerLiquidity = currentFee0PerLiquidity - positionState.fee0PerLiquidity;
        }
        deltaFee0PerLiquidity =
            bound(deltaFee0PerLiquidity, 0, type(uint128).max * uint256(1e18) / positionState.amountWrapped);
        unchecked {
            positionState.fee0PerLiquidity = currentFee0PerLiquidity - uint128(deltaFee0PerLiquidity);
        }

        // And: The fee0 balance of the position plus the newly earned fee0 stays within uint128.
        uint256 deltaFee0 = deltaFee0PerLiquidity * uint256(positionState.amountWrapped) / 1e18;
        positionState.fee0 = uint128(bound(positionState.fee0, 0, type(uint128).max - deltaFee0));

        // And: The pool advanced its fee1 accumulator by the accrued fee1.
        uint256 deltaFee1PerLiquidity = fee1 * 1e18 / poolState.totalWrapped;
        uint128 currentFee1PerLiquidity;
        unchecked {
            currentFee1PerLiquidity = poolState.fee1PerLiquidity + uint128(deltaFee1PerLiquidity);
        }

        // And: The position newly earns at least 1 wei of fee1.
        unchecked {
            deltaFee1PerLiquidity = currentFee1PerLiquidity - positionState.fee1PerLiquidity;
        }
        deltaFee1PerLiquidity = bound(deltaFee1PerLiquidity, 1e18 / positionState.amountWrapped + 1, type(uint128).max);
        unchecked {
            positionState.fee1PerLiquidity = currentFee1PerLiquidity - uint128(deltaFee1PerLiquidity);
        }

        // And: The fee1 balance of the position plus the newly earned fee1 exceeds uint128.
        uint256 deltaFee1 = deltaFee1PerLiquidity * positionState.amountWrapped / 1e18;
        positionState.fee1 = uint128(
            bound(
                positionState.fee1,
                deltaFee1 > type(uint128).max ? 0 : type(uint128).max - deltaFee1 + 1,
                type(uint128).max
            )
        );

        // When: The fee balances are calculated.
        // Then: It reverts on the overflow of the fee1 balance of the position.
        vm.expectRevert(bytes(""));
        wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);
    }

    function testFuzz_Success_getFeeBalances_NonZeroTotalWrapped(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public view {
        // Given: A valid wrapped state.
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);

        // When: The fee balances are calculated.
        (WrappedAerodromeAM.PoolState memory poolState_, WrappedAerodromeAM.PositionState memory positionState_) =
            wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);

        // Then: Both pool accumulators grew by the accrued fees per unit of liquidity.
        uint128 fee0PerLiquidity;
        uint128 fee1PerLiquidity;
        unchecked {
            fee0PerLiquidity = poolState.fee0PerLiquidity + uint128(fee0.mulDivDown(1e18, poolState.totalWrapped));
            fee1PerLiquidity = poolState.fee1PerLiquidity + uint128(fee1.mulDivDown(1e18, poolState.totalWrapped));
        }
        assertEq(poolState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, poolState.totalWrapped);

        // And: The position caught up with both accumulators and earned its share of the fees.
        uint128 deltaFee0PerLiquidity;
        uint128 deltaFee1PerLiquidity;
        unchecked {
            deltaFee0PerLiquidity = fee0PerLiquidity - positionState.fee0PerLiquidity;
            deltaFee1PerLiquidity = fee1PerLiquidity - positionState.fee1PerLiquidity;
        }
        uint256 deltaFee0 = uint256(positionState.amountWrapped).mulDivDown(deltaFee0PerLiquidity, 1e18);
        uint256 deltaFee1 = uint256(positionState.amountWrapped).mulDivDown(deltaFee1PerLiquidity, 1e18);
        assertEq(positionState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(positionState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(positionState_.fee0, positionState.fee0 + deltaFee0);
        assertEq(positionState_.fee1, positionState.fee1 + deltaFee1);
        assertEq(positionState_.amountWrapped, positionState.amountWrapped);
        assertEq(positionState_.pool, positionState.pool);
    }

    function testFuzz_Success_getFeeBalances_NonZeroTotalWrapped_CapDeltaFee0PerLiquidity(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public view {
        // Given: A non-zero wrapped total of at most 1e18.
        poolState.totalWrapped = uint128(bound(poolState.totalWrapped, 1, 1e18));

        // And: The accrued fee0 exceeds what the fee0 accumulator can represent.
        fee0 = bound(fee0, uint256(type(uint128).max) * poolState.totalWrapped / 1e18 + 1, type(uint256).max / 1e18);

        // And: The accrued fee1 stays within what the fee1 accumulator can represent.
        fee1 = bound(fee1, 0, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);

        // And: The position wraps at most the total wrapped amount, zero included.
        positionState.amountWrapped = uint128(bound(positionState.amountWrapped, 0, poolState.totalWrapped));

        // And: The fee0 accumulator grew by the capped amount, the fee1 accumulator by the accrued fee1.
        uint128 fee0PerLiquidity;
        uint128 fee1PerLiquidity;
        unchecked {
            fee0PerLiquidity = poolState.fee0PerLiquidity + type(uint128).max;
            fee1PerLiquidity = poolState.fee1PerLiquidity + uint128(fee1.mulDivDown(1e18, poolState.totalWrapped));
        }

        // And: The position earns its share of the growth of both accumulators.
        uint128 deltaFee0PerLiquidity;
        uint128 deltaFee1PerLiquidity;
        unchecked {
            deltaFee0PerLiquidity = fee0PerLiquidity - positionState.fee0PerLiquidity;
            deltaFee1PerLiquidity = fee1PerLiquidity - positionState.fee1PerLiquidity;
        }
        uint256 deltaFee0 = uint256(positionState.amountWrapped).mulDivDown(deltaFee0PerLiquidity, 1e18);
        uint256 deltaFee1 = uint256(positionState.amountWrapped).mulDivDown(deltaFee1PerLiquidity, 1e18);

        // And: Both fee balances of the position stay within uint128.
        positionState.fee0 = uint128(bound(positionState.fee0, 0, type(uint128).max - deltaFee0));
        positionState.fee1 = uint128(bound(positionState.fee1, 0, type(uint128).max - deltaFee1));

        // When: The fee balances are calculated.
        (WrappedAerodromeAM.PoolState memory poolState_, WrappedAerodromeAM.PositionState memory positionState_) =
            wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);

        // Then: The growth of the fee0 accumulator is capped at uint128.
        assertEq(poolState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, poolState.totalWrapped);

        // And: The capped growth is credited to the position.
        assertEq(positionState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(positionState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(positionState_.fee0, positionState.fee0 + deltaFee0);
        assertEq(positionState_.fee1, positionState.fee1 + deltaFee1);
        assertEq(positionState_.amountWrapped, positionState.amountWrapped);
        assertEq(positionState_.pool, positionState.pool);
    }

    function testFuzz_Success_getFeeBalances_NonZeroTotalWrapped_CapDeltaFee1PerLiquidity(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public view {
        // Given: A non-zero wrapped total of at most 1e18.
        poolState.totalWrapped = uint128(bound(poolState.totalWrapped, 1, 1e18));

        // And: The accrued fee0 stays within what the fee0 accumulator can represent.
        fee0 = bound(fee0, 0, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);

        // And: The accrued fee1 exceeds what the fee1 accumulator can represent.
        fee1 = bound(fee1, uint256(type(uint128).max) * poolState.totalWrapped / 1e18 + 1, type(uint256).max / 1e18);

        // And: The position wraps at most the total wrapped amount, zero included.
        positionState.amountWrapped = uint128(bound(positionState.amountWrapped, 0, poolState.totalWrapped));

        // And: The fee1 accumulator grew by the capped amount, the fee0 accumulator by the accrued fee0.
        uint128 fee0PerLiquidity;
        uint128 fee1PerLiquidity;
        unchecked {
            fee0PerLiquidity = poolState.fee0PerLiquidity + uint128(fee0.mulDivDown(1e18, poolState.totalWrapped));
            fee1PerLiquidity = poolState.fee1PerLiquidity + type(uint128).max;
        }

        // And: The position earns its share of the growth of both accumulators.
        uint128 deltaFee0PerLiquidity;
        uint128 deltaFee1PerLiquidity;
        unchecked {
            deltaFee0PerLiquidity = fee0PerLiquidity - positionState.fee0PerLiquidity;
            deltaFee1PerLiquidity = fee1PerLiquidity - positionState.fee1PerLiquidity;
        }
        uint256 deltaFee0 = uint256(positionState.amountWrapped).mulDivDown(deltaFee0PerLiquidity, 1e18);
        uint256 deltaFee1 = uint256(positionState.amountWrapped).mulDivDown(deltaFee1PerLiquidity, 1e18);

        // And: Both fee balances of the position stay within uint128.
        positionState.fee0 = uint128(bound(positionState.fee0, 0, type(uint128).max - deltaFee0));
        positionState.fee1 = uint128(bound(positionState.fee1, 0, type(uint128).max - deltaFee1));

        // When: The fee balances are calculated.
        (WrappedAerodromeAM.PoolState memory poolState_, WrappedAerodromeAM.PositionState memory positionState_) =
            wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);

        // Then: The growth of the fee1 accumulator is capped at uint128.
        assertEq(poolState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, poolState.totalWrapped);

        // And: The capped growth is credited to the position.
        assertEq(positionState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(positionState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(positionState_.fee0, positionState.fee0 + deltaFee0);
        assertEq(positionState_.fee1, positionState.fee1 + deltaFee1);
        assertEq(positionState_.amountWrapped, positionState.amountWrapped);
        assertEq(positionState_.pool, positionState.pool);
    }

    function testFuzz_Success_getFeeBalances_ZeroTotalWrapped(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    ) public view {
        // Given: Nothing is wrapped.
        poolState.totalWrapped = 0;

        // When: The fee balances are calculated.
        (WrappedAerodromeAM.PoolState memory poolState_, WrappedAerodromeAM.PositionState memory positionState_) =
            wrappedAerodromeAM.getFeeBalances(poolState, positionState, fee0, fee1);

        // Then: Neither pool accumulator advanced.
        assertEq(poolState_.fee0PerLiquidity, poolState.fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, poolState.fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, poolState.totalWrapped);

        // And: The position caught up with both accumulators but earned nothing.
        assertEq(positionState_.fee0PerLiquidity, poolState.fee0PerLiquidity);
        assertEq(positionState_.fee1PerLiquidity, poolState.fee1PerLiquidity);
        assertEq(positionState_.fee0, positionState.fee0);
        assertEq(positionState_.fee1, positionState.fee1);
        assertEq(positionState_.amountWrapped, positionState.amountWrapped);
        assertEq(positionState_.pool, positionState.pool);
    }
}
