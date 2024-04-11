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
 * @notice Fuzz tests for the function "mint" of contract "WrappedAerodromeAM".
 */
contract Mint_WrappedAerodromeAM_Fuzz_Test is WrappedAerodromeAM_Fuzz_Test {
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

    function testFuzz_Revert_mint_ZeroAmount(address pool_) public {
        // The stake function should revert when trying to stake 0 amount.
        vm.expectRevert(WrappedAerodromeAM.ZeroAmount.selector);
        wrappedAerodromeAM.mint(pool_, 0);
    }

    function testFuzz_Revert_mint_PoolNotAllowed(uint128 amount, bool stable, address account) public {
        // Given : Amount is greater than zero
        vm.assume(amount > 0);

        // Given : Valid pool
        pool = Pool(poolFactory.createPool(address(asset0), address(asset1), stable));
        vm.assume(account != address(pool));
        vm.assume(account != pool.poolFees());

        // When : Calling Stake
        // Then : The function should revert as the asset has not been added to the Staking Module.
        vm.prank(account);
        vm.expectRevert(WrappedAerodromeAM.PoolNotAllowed.selector);
        wrappedAerodromeAM.mint(address(pool), amount);
    }

    function testFuzz_Success_mint_TotalWrappedGreaterThan0(
        bool stable,
        WrappedAerodromeAM.PoolState memory poolState,
        address account,
        uint256 fee0,
        uint256 fee1,
        uint128 amount
    ) public canReceiveERC721(account) {
        // Given : Valid pool
        pool = Pool(poolFactory.createPool(address(asset0), address(asset1), stable));
        vm.assume(account != address(pool));
        vm.assume(account != pool.poolFees());

        // And: Valid state.
        WrappedAerodromeAM.PositionState memory positionState;
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);

        // And: Amount staked is greater than zero.
        vm.assume(poolState.totalWrapped < type(uint128).max);
        amount = uint128(bound(amount, 1, type(uint128).max - poolState.totalWrapped));

        // And: State is persisted.
        setAMState(pool, 0, poolState, positionState);
        pool.setClaimables(address(wrappedAerodromeAM), fee0, fee1);
        deal(address(pool), account, amount, true);
        deal(pool.token0(), pool.poolFees(), fee0, true);
        deal(pool.token1(), pool.poolFees(), fee1, true);

        // When:  A user is staking via the Staking Module.
        vm.startPrank(account);
        pool.approve(address(wrappedAerodromeAM), amount);
        vm.expectEmit();
        emit WrappedAerodromeAM.LiquidityIncreased(1, address(pool), amount);
        uint256 positionId = wrappedAerodromeAM.mint(address(pool), amount);

        // Then: Assets should have been transferred to the Staking Module.
        assertEq(pool.balanceOf(address(wrappedAerodromeAM)), poolState.totalWrapped + amount);
        assertEq(ERC20(pool.token0()).balanceOf(address(wrappedAerodromeAM)), fee0);
        assertEq(ERC20(pool.token1()).balanceOf(address(wrappedAerodromeAM)), fee1);

        // And: New position has been minted to Account.
        assertEq(wrappedAerodromeAM.ownerOf(positionId), account);

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
        assertEq(positionState_.amountWrapped, amount);
        assertEq(positionState_.pool, address(pool));

        // And: Asset state should be updated correctly.
        WrappedAerodromeAM.PoolState memory poolState_;
        (poolState_.fee0PerLiquidity, poolState_.fee1PerLiquidity, poolState_.totalWrapped) =
            wrappedAerodromeAM.poolState(address(pool));

        assertEq(poolState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, poolState.totalWrapped + amount);
    }

    function testFuzz_Success_mint_TotalWrappedIsZero(
        bool stable,
        WrappedAerodromeAM.PoolState memory poolState,
        address account,
        uint256 fee0,
        uint256 fee1,
        uint128 amount
    ) public canReceiveERC721(account) {
        // Given : Valid pool
        pool = Pool(poolFactory.createPool(address(asset0), address(asset1), stable));
        vm.assume(account != address(pool));
        vm.assume(account != pool.poolFees());

        // And: Valid state.
        WrappedAerodromeAM.PositionState memory positionState;
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);

        // And: TotalStaked is 0.
        poolState.totalWrapped = 0;

        // And: Amount staked is greater than zero.
        amount = uint128(bound(amount, 1, type(uint128).max));

        // And: State is persisted.
        setAMState(pool, 0, poolState, positionState);
        pool.setClaimables(address(wrappedAerodromeAM), fee0, fee1);
        deal(address(pool), account, amount, true);
        deal(pool.token0(), pool.poolFees(), fee0, true);
        deal(pool.token1(), pool.poolFees(), fee1, true);

        // When:  A user is staking via the Staking Module.
        vm.startPrank(account);
        pool.approve(address(wrappedAerodromeAM), amount);
        vm.expectEmit();
        emit WrappedAerodromeAM.LiquidityIncreased(1, address(pool), amount);
        uint256 positionId = wrappedAerodromeAM.mint(address(pool), amount);

        // Then: Assets should have been transferred to the Staking Module.
        assertEq(pool.balanceOf(address(wrappedAerodromeAM)), poolState.totalWrapped + amount);

        // And: New position has been minted to Account.
        assertEq(wrappedAerodromeAM.ownerOf(positionId), account);

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
        assertEq(positionState_.fee0PerLiquidity, poolState.fee0PerLiquidity);
        assertEq(positionState_.fee1PerLiquidity, poolState.fee1PerLiquidity);
        assertEq(positionState_.fee0, 0);
        assertEq(positionState_.fee1, 0);
        assertEq(positionState_.amountWrapped, amount);
        assertEq(positionState_.pool, address(pool));

        // And: Asset state should be updated correctly.
        WrappedAerodromeAM.PoolState memory poolState_;
        (poolState_.fee0PerLiquidity, poolState_.fee1PerLiquidity, poolState_.totalWrapped) =
            wrappedAerodromeAM.poolState(address(pool));

        assertEq(poolState_.fee0PerLiquidity, poolState.fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, poolState.fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, poolState.totalWrapped + amount);
    }
}
