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
 * @notice Fuzz tests for the function "increaseLiquidity" of contract "WrappedMetadex03AM".
 */
contract IncreaseLiquidity_WrappedMetadex03AM_Fuzz_Test is WrappedMetadex03AM_Fuzz_Test {
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

    function testFuzz_Revert_increaseLiquidity_ZeroAmount(uint96 positionId) public {
        // Given: An arbitrary position.

        // When: The liquidity of the position is increased by a zero amount.
        // Then: It reverts.
        vm.expectRevert(WrappedAerodromeAM.ZeroAmount.selector);
        wrappedMetadex03AM.increaseLiquidity(positionId, 0);
    }

    function testFuzz_Revert_increaseLiquidity_NotOwner(
        address owner,
        address randomAddress,
        uint128 amount,
        uint96 positionId
    ) public canReceiveERC721(owner) {
        // Given: The amount to wrap is non-zero.
        vm.assume(amount != 0);

        // And: An existing position owned by the owner.
        vm.assume(positionId != 0);
        wrappedMetadex03AM.setOwnerOf(owner, positionId);

        // And: The random address does not own the position.
        vm.assume(owner != randomAddress);

        // When: The liquidity of the position is increased.
        // Then: It reverts.
        vm.startPrank(randomAddress);
        vm.expectRevert(WrappedAerodromeAM.NotOwner.selector);
        wrappedMetadex03AM.increaseLiquidity(positionId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_increaseLiquidity(
        bool stable,
        address owner,
        uint96 positionId,
        uint256 fee0,
        uint256 fee1,
        WrappedAerodromeAM.PositionState memory positionState,
        WrappedAerodromeAM.PoolState memory poolState,
        uint128 amount
    ) public canReceiveERC721(owner) {
        // Given: A pool with a valid wrapped state.
        metadex03Pool = createPoolMetadex03(address(asset0), address(asset1), stable);
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);

        // And: The wrapped total leaves room for the newly wrapped amount.
        vm.assume(poolState.totalWrapped < type(uint128).max);
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 1, type(uint128).max - poolState.totalWrapped));

        // And: That state is persisted and the pool holds claimable fees.
        setAMState(metadex03Pool, positionId, poolState, positionState);
        setClaimables(metadex03Pool, address(wrappedMetadex03AM), fee0, fee1);
        deal(metadex03Pool.token0(), metadex03Pool.poolFees(), fee0, true);
        deal(metadex03Pool.token1(), metadex03Pool.poolFees(), fee1, true);
        wrappedMetadex03AM.setOwnerOf(owner, positionId);

        // And: The owner holds the liquidity and approved the Asset Module.
        vm.assume(owner != address(metadex03Pool));
        vm.assume(owner != metadex03Pool.poolFees());
        deal(address(metadex03Pool), owner, amount, true);
        vm.startPrank(owner);
        metadex03Pool.approve(address(wrappedMetadex03AM), amount);

        // When: The owner increases the liquidity of the position.
        // Then: A LiquidityIncreased event is emitted.
        vm.expectEmit();
        emit WrappedAerodromeAM.LiquidityIncreased(positionId, address(metadex03Pool), amount);
        wrappedMetadex03AM.increaseLiquidity(positionId, amount);
        vm.stopPrank();

        // And: The wrapped liquidity and the claimed pool fees sit in the Asset Module.
        assertEq(metadex03Pool.balanceOf(address(wrappedMetadex03AM)), poolState.totalWrapped + amount);
        assertEq(ERC20(metadex03Pool.token0()).balanceOf(address(wrappedMetadex03AM)), fee0);
        assertEq(ERC20(metadex03Pool.token1()).balanceOf(address(wrappedMetadex03AM)), fee1);

        // And: The fees earned since the last interaction are credited to the position.
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
        uint128 deltaFee0PerLiquidity;
        uint128 deltaFee1PerLiquidity;
        unchecked {
            deltaFee0PerLiquidity = fee0PerLiquidity - positionState.fee0PerLiquidity;
            deltaFee1PerLiquidity = fee1PerLiquidity - positionState.fee1PerLiquidity;
        }
        uint256 deltaFee0 = uint256(positionState.amountWrapped).mulDivDown(deltaFee0PerLiquidity, 1e18);
        uint256 deltaFee1 = uint256(positionState.amountWrapped).mulDivDown(deltaFee1PerLiquidity, 1e18);
        assertEq(positionState_.fee0, positionState.fee0 + deltaFee0);
        assertEq(positionState_.fee1, positionState.fee1 + deltaFee1);
        assertEq(positionState_.amountWrapped, positionState.amountWrapped + amount);
        assertEq(positionState_.pool, address(metadex03Pool));

        // And: The pool accumulators advanced and the wrapped total grew by the amount.
        WrappedAerodromeAM.PoolState memory poolState_;
        (poolState_.fee0PerLiquidity, poolState_.fee1PerLiquidity, poolState_.totalWrapped) =
            wrappedMetadex03AM.poolState(address(metadex03Pool));

        assertEq(poolState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, poolState.totalWrapped + amount);
    }
}
