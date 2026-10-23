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
 * @notice Fuzz tests for the function "mint" of contract "WrappedMetadex03AM".
 */
contract Mint_WrappedMetadex03AM_Fuzz_Test is WrappedMetadex03AM_Fuzz_Test {
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

    function testFuzz_Revert_mint_ZeroAmount(address pool_) public {
        // Given: An arbitrary pool.

        // When: A position is minted for a zero amount.
        // Then: It reverts.
        vm.expectRevert(WrappedAerodromeAM.ZeroAmount.selector);
        wrappedMetadex03AM.mint(pool_, 0);
    }

    function testFuzz_Revert_mint_PoolNotAllowed(uint128 amount, bool stable, address account_) public {
        // Given: A pool that is not added as an asset.
        metadex03Pool = createPoolMetadex03(address(asset0), address(asset1), stable);

        // And: The amount to wrap is non-zero.
        vm.assume(amount != 0);

        // And: The account is neither the pool nor its fee vault.
        vm.assume(account_ != address(metadex03Pool));
        vm.assume(account_ != metadex03Pool.poolFees());

        // When: A position is minted.
        // Then: It reverts.
        vm.prank(account_);
        vm.expectRevert(WrappedAerodromeAM.PoolNotAllowed.selector);
        wrappedMetadex03AM.mint(address(metadex03Pool), amount);
    }

    function testFuzz_Success_mint_TotalWrappedGreaterThan0(
        bool stable,
        WrappedAerodromeAM.PoolState memory poolState,
        address account_,
        uint256 fee0,
        uint256 fee1,
        uint128 amount
    ) public canReceiveERC721(account_) {
        // Given: A pool with a valid wrapped state.
        metadex03Pool = createPoolMetadex03(address(asset0), address(asset1), stable);
        WrappedAerodromeAM.PositionState memory positionState;
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);

        // And: The wrapped total leaves room for the newly wrapped amount.
        vm.assume(poolState.totalWrapped < type(uint128).max);
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 1, type(uint128).max - poolState.totalWrapped));

        // And: That state is persisted and the pool holds claimable fees.
        setAMState(metadex03Pool, 0, poolState, positionState);
        setClaimables(metadex03Pool, address(wrappedMetadex03AM), fee0, fee1);
        deal(metadex03Pool.token0(), metadex03Pool.poolFees(), fee0, true);
        deal(metadex03Pool.token1(), metadex03Pool.poolFees(), fee1, true);

        // And: The account holds the liquidity and approved the Asset Module.
        vm.assume(account_ != address(metadex03Pool));
        vm.assume(account_ != metadex03Pool.poolFees());
        deal(address(metadex03Pool), account_, amount, true);
        vm.startPrank(account_);
        metadex03Pool.approve(address(wrappedMetadex03AM), amount);

        // When: The account mints a position.
        // Then: A LiquidityIncreased event is emitted.
        vm.expectEmit();
        emit WrappedAerodromeAM.LiquidityIncreased(1, address(metadex03Pool), amount);
        uint256 positionId = wrappedMetadex03AM.mint(address(metadex03Pool), amount);
        vm.stopPrank();

        // And: The wrapped liquidity and the claimed pool fees sit in the Asset Module.
        assertEq(metadex03Pool.balanceOf(address(wrappedMetadex03AM)), poolState.totalWrapped + amount);
        assertEq(ERC20(metadex03Pool.token0()).balanceOf(address(wrappedMetadex03AM)), fee0);
        assertEq(ERC20(metadex03Pool.token1()).balanceOf(address(wrappedMetadex03AM)), fee1);

        // And: The new position is owned by the account.
        assertEq(wrappedMetadex03AM.ownerOf(positionId), account_);

        // And: The position starts at the new fee accumulators with a zero fee balance.
        WrappedAerodromeAM.PositionState memory positionState_;
        (
            positionState_.fee0PerLiquidity,
            positionState_.fee1PerLiquidity,
            positionState_.fee0,
            positionState_.fee1,
            positionState_.amountWrapped,
            positionState_.pool
        ) = wrappedMetadex03AM.positionState(positionId);

        uint128 fee0PerLiquidity;
        uint128 fee1PerLiquidity;
        unchecked {
            // forge-lint: disable-next-item(unsafe-typecast)
            fee0PerLiquidity = poolState.fee0PerLiquidity + uint128(fee0.mulDivDown(1e18, poolState.totalWrapped));
            // forge-lint: disable-next-item(unsafe-typecast)
            fee1PerLiquidity = poolState.fee1PerLiquidity + uint128(fee1.mulDivDown(1e18, poolState.totalWrapped));
        }
        assertEq(positionState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(positionState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(positionState_.fee0, 0);
        assertEq(positionState_.fee1, 0);
        assertEq(positionState_.amountWrapped, amount);
        assertEq(positionState_.pool, address(metadex03Pool));

        // And: The pool accumulators advanced and the wrapped total grew by the amount.
        WrappedAerodromeAM.PoolState memory poolState_;
        (poolState_.fee0PerLiquidity, poolState_.fee1PerLiquidity, poolState_.totalWrapped) =
            wrappedMetadex03AM.poolState(address(metadex03Pool));

        assertEq(poolState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, poolState.totalWrapped + amount);
    }

    function testFuzz_Success_mint_TotalWrappedIsZero(
        bool stable,
        WrappedAerodromeAM.PoolState memory poolState,
        address account_,
        uint256 fee0,
        uint256 fee1,
        uint128 amount
    ) public canReceiveERC721(account_) {
        // Given: A pool with a valid wrapped state.
        metadex03Pool = createPoolMetadex03(address(asset0), address(asset1), stable);
        WrappedAerodromeAM.PositionState memory positionState;
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);

        // And: Nothing is wrapped yet.
        poolState.totalWrapped = 0;

        // And: The amount to wrap is non-zero.
        vm.assume(amount != 0);

        // And: That state is persisted and the pool holds claimable fees.
        setAMState(metadex03Pool, 0, poolState, positionState);
        setClaimables(metadex03Pool, address(wrappedMetadex03AM), fee0, fee1);
        deal(metadex03Pool.token0(), metadex03Pool.poolFees(), fee0, true);
        deal(metadex03Pool.token1(), metadex03Pool.poolFees(), fee1, true);

        // And: The account holds the liquidity and approved the Asset Module.
        vm.assume(account_ != address(metadex03Pool));
        vm.assume(account_ != metadex03Pool.poolFees());
        deal(address(metadex03Pool), account_, amount, true);
        vm.startPrank(account_);
        metadex03Pool.approve(address(wrappedMetadex03AM), amount);

        // When: The account mints a position.
        // Then: A LiquidityIncreased event is emitted.
        vm.expectEmit();
        emit WrappedAerodromeAM.LiquidityIncreased(1, address(metadex03Pool), amount);
        uint256 positionId = wrappedMetadex03AM.mint(address(metadex03Pool), amount);
        vm.stopPrank();

        // And: The wrapped liquidity sits in the Asset Module.
        assertEq(metadex03Pool.balanceOf(address(wrappedMetadex03AM)), poolState.totalWrapped + amount);

        // And: The new position is owned by the account.
        assertEq(wrappedMetadex03AM.ownerOf(positionId), account_);

        // And: The fee accumulators did not advance.
        WrappedAerodromeAM.PositionState memory positionState_;
        (
            positionState_.fee0PerLiquidity,
            positionState_.fee1PerLiquidity,
            positionState_.fee0,
            positionState_.fee1,
            positionState_.amountWrapped,
            positionState_.pool
        ) = wrappedMetadex03AM.positionState(positionId);
        assertEq(positionState_.fee0PerLiquidity, poolState.fee0PerLiquidity);
        assertEq(positionState_.fee1PerLiquidity, poolState.fee1PerLiquidity);
        assertEq(positionState_.fee0, 0);
        assertEq(positionState_.fee1, 0);
        assertEq(positionState_.amountWrapped, amount);
        assertEq(positionState_.pool, address(metadex03Pool));

        // And: The wrapped total grew by the amount.
        WrappedAerodromeAM.PoolState memory poolState_;
        (poolState_.fee0PerLiquidity, poolState_.fee1PerLiquidity, poolState_.totalWrapped) =
            wrappedMetadex03AM.poolState(address(metadex03Pool));

        assertEq(poolState_.fee0PerLiquidity, poolState.fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, poolState.fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, poolState.totalWrapped + amount);
    }
}
