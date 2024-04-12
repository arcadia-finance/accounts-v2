/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { Pool } from "../../../utils/fixtures/aerodrome/AeroPoolFixture.f.sol";
import { stdError } from "../../../../lib/forge-std/src/StdError.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

/**
 * @notice Fuzz tests for the function "decreaseLiquidity" of contract "WrappedAerodromeAM".
 */
contract DecreaseLiquidity_WrappedAerodromeAM_Fuzz_Test is WrappedAerodromeAM_Fuzz_Test {
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

    function testFuzz_Revert_decreaseLiquidity_ZeroAmount(uint256 positionId) public {
        // When : Trying to withdraw zero amount.
        // Then : It should revert.
        vm.expectRevert(WrappedAerodromeAM.ZeroAmount.selector);
        wrappedAerodromeAM.decreaseLiquidity(positionId, 0);
    }

    function testFuzz_Revert_decreaseLiquidity_NotOwner(
        address owner,
        address randomAddress,
        uint128 amount,
        uint96 positionId
    ) public {
        // Given : Amount is greater than zero
        amount = uint128(bound(amount, 1, type(uint128).max));

        // Given : Owner of positionId is not the randomAddress
        vm.assume(owner != randomAddress);
        wrappedAerodromeAM.setOwnerOf(owner, positionId);

        // When : Trying to withdraw a position not owned by the caller.
        // Then : It should revert.
        vm.startPrank(randomAddress);
        vm.expectRevert(WrappedAerodromeAM.NotOwner.selector);
        wrappedAerodromeAM.decreaseLiquidity(positionId, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_decreaseLiquidity_RemainingBalanceTooLow(
        bool stable,
        address owner,
        uint96 positionId,
        uint256 fee0,
        uint256 fee1,
        WrappedAerodromeAM.PositionState memory positionState,
        WrappedAerodromeAM.PoolState memory poolState,
        uint128 amount
    ) public canReceiveERC721(owner) {
        // Given : Valid pool
        pool = Pool(poolFactory.createPool(address(asset0), address(asset1), stable));
        vm.assume(owner != address(pool));
        vm.assume(owner != pool.poolFees());

        // And: Valid state.
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);

        // And : Owner has a non-zero balance.
        vm.assume(positionState.amountWrapped > 0);
        // And : Owner has a balance smaller as type(uint128).max.
        vm.assume(positionState.amountWrapped < type(uint128).max);

        // And: amount withdrawn is bigger than the balance.
        amount = uint128(bound(amount, positionState.amountWrapped + 1, type(uint128).max));

        // And: State is persisted.
        setAMState(pool, positionId, poolState, positionState);
        wrappedAerodromeAM.setOwnerOf(owner, positionId);
        deal(address(pool), owner, amount, true);
        pool.setClaimables(address(wrappedAerodromeAM), fee0, fee1);
        deal(pool.token0(), pool.poolFees(), fee0, true);
        deal(pool.token1(), pool.poolFees(), fee1, true);

        // When : Calling decreaseLiquidity().
        // Then : It should revert as remaining balance is too low.
        vm.startPrank(owner);
        vm.expectRevert(stdError.arithmeticError);
        wrappedAerodromeAM.decreaseLiquidity(positionId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_decreaseLiquidity_FullWithdraw(
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

            // When : Owner withdraws full position from wrappedAerodromeAM
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

    function testFuzz_Success_decreaseLiquidity_PartialWithdraw(
        bool stable,
        address owner,
        uint96 positionId,
        uint256 fee0,
        uint256 fee1,
        WrappedAerodromeAM.PositionState memory positionState,
        WrappedAerodromeAM.PoolState memory poolState,
        uint128 amount
    ) public canReceiveERC721(owner) {
        // Given : Valid pool
        pool = Pool(poolFactory.createPool(address(asset0), address(asset1), stable));
        vm.assume(owner != address(pool));
        vm.assume(owner != pool.poolFees());

        // And: Valid state.
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);

        // And : Owner has a balance bigger as 1.
        vm.assume(positionState.amountWrapped > 1);

        // And : amount withdrawn is smaller as the staked balance.
        amount = uint128(bound(amount, 1, positionState.amountWrapped - 1));

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

            // When : Owner withdraws from wrappedAerodromeAM
            vm.startPrank(owner);
            vm.expectEmit();
            emit WrappedAerodromeAM.FeesPaid(positionId, uint128(fee0_), uint128(fee1_));
            vm.expectEmit();
            emit WrappedAerodromeAM.LiquidityDecreased(positionId, address(pool), amount);
            (uint256 fee0__, uint256 fee1__) = wrappedAerodromeAM.decreaseLiquidity(positionId, amount);
            vm.stopPrank();

            // Then : Claimed rewards are returned.
            assertEq(fee0_, fee0__);
            assertEq(fee1_, fee1__);

            // And : Owner should get the withdrawn amount and reward tokens.
            assertEq(pool.balanceOf(owner), amount);
            assertEq(ERC20(pool.token0()).balanceOf(owner), fee0_);
            assertEq(ERC20(pool.token1()).balanceOf(owner), fee1_);

            // And : Staking Module should have the remaining tokens
            assertEq(pool.balanceOf(address(wrappedAerodromeAM)), poolState.totalWrapped - amount);

            // And : positionId should not be burned.
            assertEq(wrappedAerodromeAM.balanceOf(owner), 1);
        }

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

        uint128 fee0PerLiquidity;
        uint128 fee1PerLiquidity;
        unchecked {
            fee0PerLiquidity = poolState.fee0PerLiquidity + uint128(fee0.mulDivDown(1e18, poolState.totalWrapped));
            fee1PerLiquidity = poolState.fee1PerLiquidity + uint128(fee1.mulDivDown(1e18, poolState.totalWrapped));
        }
        assertEq(positionState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(positionState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(positionState_.fee0, 0);
        assertEq(positionState_.fee1, 0);
        assertEq(positionState_.amountWrapped, positionState.amountWrapped - amount);
        assertEq(positionState_.pool, address(pool));

        // And : Asset values should be updated correctly
        WrappedAerodromeAM.PoolState memory poolState_;
        (poolState_.fee0PerLiquidity, poolState_.fee1PerLiquidity, poolState_.totalWrapped) =
            wrappedAerodromeAM.poolState(address(pool));

        assertEq(poolState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, poolState.totalWrapped - amount);
    }
}
