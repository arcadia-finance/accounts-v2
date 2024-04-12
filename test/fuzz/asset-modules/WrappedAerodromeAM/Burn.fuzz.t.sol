/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { Pool } from "../../../utils/fixtures/aerodrome/AeroPoolFixture.f.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

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
        // When : Trying to burn a non existing position.
        // Then : It should revert.
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
        // Given : Owner of positionId is not the randomAddress
        vm.assume(owner != randomAddress);

        // And : Valid pool
        pool = Pool(poolFactory.createPool(address(asset0), address(asset1), stable));
        vm.assume(owner != address(pool));
        vm.assume(owner != pool.poolFees());

        // And : Amount wrapped is greater than 0.
        positionState.amountWrapped = uint128(bound(positionState.amountWrapped, 1, type(uint128).max));

        // And: State is persisted.
        setAMState(pool, positionId, poolState, positionState);
        wrappedAerodromeAM.mintIdTo(owner, positionId);

        // When : Trying to withdraw a position not owned by the caller.
        // Then : It should revert.
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
        vm.assume(owner != address(0));

        // Given : Valid pool
        pool = Pool(poolFactory.createPool(address(asset0), address(asset1), stable));
        vm.assume(owner != address(pool));
        vm.assume(owner != pool.poolFees());

        // And: Valid state.
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);

        // And : Owner has a non-zero balance.
        vm.assume(positionState.amountWrapped > 0);

        // And: State is persisted.
        setAMState(pool, positionId, poolState, positionState);
        pool.setClaimables(address(wrappedAerodromeAM), fee0, fee1);
        deal(pool.token0(), pool.poolFees(), fee0, true);
        deal(pool.token1(), pool.poolFees(), fee1, true);
        wrappedAerodromeAM.mintIdTo(owner, positionId);

        {
            // And: AM holds sufficient funds from past fees.
            (uint256 fee0_, uint256 fee1_) = wrappedAerodromeAM.feesOf(positionId);
            deal(pool.token0(), address(wrappedAerodromeAM), fee0_, true);
            deal(pool.token1(), address(wrappedAerodromeAM), fee1_, true);

            // When : Account withdraws from stakingAM
            vm.startPrank(owner);
            vm.expectEmit();
            emit WrappedAerodromeAM.FeesPaid(positionId, uint128(fee0_), uint128(fee1_));
            vm.expectEmit();
            emit WrappedAerodromeAM.LiquidityDecreased(positionId, address(pool), positionState.amountWrapped);
            (uint256 fee0__, uint256 fee1__) =
                wrappedAerodromeAM.decreaseLiquidity(positionId, positionState.amountWrapped);
            vm.stopPrank();

            // Then : Claimed rewards are returned.
            assertEq(fee0_, fee0__);
            assertEq(fee1_, fee1__);

            // And : Owner should get the staking and reward tokens
            assertEq(pool.balanceOf(owner), positionState.amountWrapped);
            assertEq(ERC20(pool.token0()).balanceOf(owner), fee0_);
            assertEq(ERC20(pool.token1()).balanceOf(owner), fee1_);

            // And : Staking Module should have the remaining tokens
            assertEq(pool.balanceOf(address(wrappedAerodromeAM)), poolState.totalWrapped - positionState.amountWrapped);
        }

        // And : positionId should be burned.
        assertEq(wrappedAerodromeAM.balanceOf(owner), 0);

        // And: Position state should be updated correctly.
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

        // And: Asset state should be updated correctly.
        WrappedAerodromeAM.PoolState memory poolState_;
        (poolState_.fee0PerLiquidity, poolState_.fee1PerLiquidity, poolState_.totalWrapped) =
            wrappedAerodromeAM.poolState(address(pool));

        uint128 fee0PerLiquidity;
        uint128 fee1PerLiquidity;
        unchecked {
            fee0PerLiquidity = poolState.fee0PerLiquidity + uint128(fee0.mulDivDown(1e18, poolState.totalWrapped));
            fee1PerLiquidity = poolState.fee1PerLiquidity + uint128(fee1.mulDivDown(1e18, poolState.totalWrapped));
        }
        assertEq(poolState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, poolState.totalWrapped - positionState.amountWrapped);
    }
}
