/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";
import { WrappedMetadex03AM_Fuzz_Test } from "./_WrappedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "burn" of contract "WrappedMetadex03AM".
 */
contract Burn_WrappedMetadex03AM_Fuzz_Test is WrappedMetadex03AM_Fuzz_Test {
    using FixedPointMathLib for uint256;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        WrappedMetadex03AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_burn_NonExistingPosition(uint256 positionId) public {
        // Given: A position that was never minted.

        // When: The position is burned.
        // Then: It reverts.
        vm.expectRevert(WrappedAerodromeAM.ZeroAmount.selector);
        wrappedMetadex03AM.burn(positionId);
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
        metadex03Pool = createPoolMetadex03(address(asset0), address(asset1), stable);
        vm.assume(owner != address(metadex03Pool));
        vm.assume(owner != metadex03Pool.poolFees());

        // And: A position of the owner that wraps a non-zero amount.
        vm.assume(positionState.amountWrapped != 0);
        setAMState(metadex03Pool, positionId, poolState, positionState);
        wrappedMetadex03AM.mintIdTo(owner, positionId);

        // And: The random address does not own the position.
        vm.assume(owner != randomAddress);

        // When: The position is burned.
        // Then: It reverts.
        vm.startPrank(randomAddress);
        vm.expectRevert(WrappedAerodromeAM.NotOwner.selector);
        wrappedMetadex03AM.burn(positionId);
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
        metadex03Pool = createPoolMetadex03(address(asset0), address(asset1), stable);
        vm.assume(owner != address(metadex03Pool));
        vm.assume(owner != metadex03Pool.poolFees());
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);

        // And: That state is persisted and the pool holds claimable fees.
        setAMState(metadex03Pool, positionId, poolState, positionState);
        setClaimables(metadex03Pool, address(wrappedMetadex03AM), fee0, fee1);
        deal(metadex03Pool.token0(), metadex03Pool.poolFees(), fee0, true);
        deal(metadex03Pool.token1(), metadex03Pool.poolFees(), fee1, true);
        wrappedMetadex03AM.mintIdTo(owner, positionId);

        {
            // And: The Asset Module holds the fees owed to the position.
            (uint256 feeOwed0, uint256 feeOwed1) = wrappedMetadex03AM.feesOf(positionId);
            deal(metadex03Pool.token0(), address(wrappedMetadex03AM), feeOwed0, true);
            deal(metadex03Pool.token1(), address(wrappedMetadex03AM), feeOwed1, true);

            // When: The owner burns the position.
            // Then: A FeesPaid and a LiquidityDecreased event are emitted.
            vm.startPrank(owner);
            vm.expectEmit();
            // forge-lint: disable-next-item(unsafe-typecast)
            emit WrappedAerodromeAM.FeesPaid(positionId, uint128(feeOwed0), uint128(feeOwed1));
            vm.expectEmit();
            emit WrappedAerodromeAM.LiquidityDecreased(positionId, address(metadex03Pool), positionState.amountWrapped);
            (uint256 feeReturned0, uint256 feeReturned1) = wrappedMetadex03AM.burn(positionId);
            vm.stopPrank();

            // And: The fees owed to the position are returned.
            assertEq(feeOwed0, feeReturned0);
            assertEq(feeOwed1, feeReturned1);

            // And: The owner receives the unwrapped liquidity and both fees.
            assertEq(metadex03Pool.balanceOf(owner), positionState.amountWrapped);
            assertEq(ERC20(metadex03Pool.token0()).balanceOf(owner), feeOwed0);
            assertEq(ERC20(metadex03Pool.token1()).balanceOf(owner), feeOwed1);

            // And: The Asset Module keeps the liquidity wrapped by other positions.
            assertEq(
                metadex03Pool.balanceOf(address(wrappedMetadex03AM)),
                poolState.totalWrapped - positionState.amountWrapped
            );
        }

        // And: The position is burned.
        assertEq(wrappedMetadex03AM.balanceOf(owner), 0);

        // And: The position state is deleted.
        WrappedAerodromeAM.PositionState memory positionState_;
        (
            positionState_.fee0PerLiquidity,
            positionState_.fee1PerLiquidity,
            positionState_.fee0,
            positionState_.fee1,
            positionState_.amountWrapped,
            positionState_.pool
        ) = wrappedMetadex03AM.positionState(positionId);

        assertEq(positionState_.fee0PerLiquidity, 0);
        assertEq(positionState_.fee1PerLiquidity, 0);
        assertEq(positionState_.fee0, 0);
        assertEq(positionState_.fee1, 0);
        assertEq(positionState_.amountWrapped, 0);
        assertEq(positionState_.pool, address(0));

        // And: The pool accumulators advanced and the wrapped total shrank by the position balance.
        WrappedAerodromeAM.PoolState memory poolState_;
        (poolState_.fee0PerLiquidity, poolState_.fee1PerLiquidity, poolState_.totalWrapped) =
            wrappedMetadex03AM.poolState(address(metadex03Pool));

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
