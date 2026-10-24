/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";
import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "burn" of contract "WrappedAerodromeAM".
 */
contract Burn_WrappedAerodromeAM_Fuzz_Test is WrappedAerodromeAM_Fuzz_Test {
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

    function testFuzz_Revert_burn_NonExistingPosition(uint256 positionId) public {
        // Given: A position that was never minted.

        // When: The position is burned.
        // Then: It reverts.
        vm.expectRevert(WrappedAerodromeAM.ZeroAmount.selector);
        wrappedAerodromeAM.burn(positionId);
    }

    function testFuzz_Revert_burn_NotOwner(
        bool stable,
        address owner,
        address randomAddress,
        uint96 positionId,
        WrappedAerodromeAM.PositionState memory positionState,
        WrappedAerodromeAM.PoolState memory poolState
    ) public canReceiveERC721(owner) {
        // Given: A pool that is added as an asset.
        aeroPool = createPoolAerodrome(address(asset0), address(asset1), stable);
        vm.assume(owner != address(aeroPool));
        vm.assume(owner != aeroPool.poolFees());

        // And: A position of the owner that wraps a non-zero amount.
        vm.assume(positionState.amountWrapped != 0);
        setAMState(aeroPool, positionId, poolState, positionState);
        wrappedAerodromeAM.mintIdTo(owner, positionId);

        // And: The random address does not own the position.
        vm.assume(owner != randomAddress);

        // When: The position is burned.
        // Then: It reverts.
        vm.startPrank(randomAddress);
        vm.expectRevert(WrappedAerodromeAM.NotOwner.selector);
        wrappedAerodromeAM.burn(positionId);
        vm.stopPrank();
    }

    function testFuzz_Success_burn(
        bool stable,
        address owner,
        uint96 positionId,
        uint256 fee0,
        uint256 fee1,
        WrappedAerodromeAM.PositionState memory positionState,
        WrappedAerodromeAM.PoolState memory poolState
    ) public canReceiveERC721(owner) {
        // Given: A pool with a valid wrapped state.
        aeroPool = createPoolAerodrome(address(asset0), address(asset1), stable);
        vm.assume(owner != address(aeroPool));
        vm.assume(owner != aeroPool.poolFees());
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);

        // And: That state is persisted and the pool holds claimable fees.
        setAMState(aeroPool, positionId, poolState, positionState);
        aeroPool.setClaimables(address(wrappedAerodromeAM), fee0, fee1);
        deal(aeroPool.token0(), aeroPool.poolFees(), fee0, true);
        deal(aeroPool.token1(), aeroPool.poolFees(), fee1, true);
        wrappedAerodromeAM.mintIdTo(owner, positionId);

        {
            // And: The Asset Module holds the fees owed to the position.
            (uint256 feeOwed0, uint256 feeOwed1) = wrappedAerodromeAM.feesOf(positionId);
            deal(aeroPool.token0(), address(wrappedAerodromeAM), feeOwed0, true);
            deal(aeroPool.token1(), address(wrappedAerodromeAM), feeOwed1, true);

            // When: The owner burns the position.
            // Then: A FeesPaid and a LiquidityDecreased event are emitted.
            vm.startPrank(owner);
            vm.expectEmit();
            // forge-lint: disable-next-item(unsafe-typecast)
            emit WrappedAerodromeAM.FeesPaid(positionId, uint128(feeOwed0), uint128(feeOwed1));
            vm.expectEmit();
            emit WrappedAerodromeAM.LiquidityDecreased(positionId, address(aeroPool), positionState.amountWrapped);
            (uint256 feeReturned0, uint256 feeReturned1) = wrappedAerodromeAM.burn(positionId);
            vm.stopPrank();

            // And: The fees owed to the position are returned.
            assertEq(feeOwed0, feeReturned0);
            assertEq(feeOwed1, feeReturned1);

            // And: The owner receives the unwrapped liquidity and both fees.
            assertEq(aeroPool.balanceOf(owner), positionState.amountWrapped);
            assertEq(ERC20(aeroPool.token0()).balanceOf(owner), feeOwed0);
            assertEq(ERC20(aeroPool.token1()).balanceOf(owner), feeOwed1);

            // And: The Asset Module keeps the liquidity wrapped by other positions.
            assertEq(
                aeroPool.balanceOf(address(wrappedAerodromeAM)), poolState.totalWrapped - positionState.amountWrapped
            );
        }

        // And: The position is burned.
        assertEq(wrappedAerodromeAM.balanceOf(owner), 0);

        // And: The position state is deleted.
        WrappedAerodromeAM.PositionState memory positionState_;
        (
            positionState_.fee0PerLiquidity,
            positionState_.fee1PerLiquidity,
            positionState_.fee0,
            positionState_.fee1,
            positionState_.amountWrapped,
            positionState_.pool
        ) = wrappedAerodromeAM.positionState(positionId);

        assertEq(positionState_.fee0PerLiquidity, 0);
        assertEq(positionState_.fee1PerLiquidity, 0);
        assertEq(positionState_.fee0, 0);
        assertEq(positionState_.fee1, 0);
        assertEq(positionState_.amountWrapped, 0);
        assertEq(positionState_.pool, address(0));

        // And: The pool accumulators advanced and the wrapped total shrank by the position balance.
        WrappedAerodromeAM.PoolState memory poolState_;
        (poolState_.fee0PerLiquidity, poolState_.fee1PerLiquidity, poolState_.totalWrapped) =
            wrappedAerodromeAM.poolState(address(aeroPool));

        uint128 fee0PerLiquidity;
        uint128 fee1PerLiquidity;
        unchecked {
            // forge-lint: disable-next-item(unsafe-typecast)
            fee0PerLiquidity = poolState.fee0PerLiquidity + uint128(fee0.mulDivDown(1e18, poolState.totalWrapped));
            // forge-lint: disable-next-item(unsafe-typecast)
            fee1PerLiquidity = poolState.fee1PerLiquidity + uint128(fee1.mulDivDown(1e18, poolState.totalWrapped));
        }
        assertEq(poolState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, poolState.totalWrapped - positionState.amountWrapped);
    }
}
