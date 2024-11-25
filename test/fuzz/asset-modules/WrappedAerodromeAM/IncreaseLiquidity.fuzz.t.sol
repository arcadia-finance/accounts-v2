/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { Pool } from "../../../utils/mocks/Aerodrome/AeroPoolMock.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

/**
 * @notice Fuzz tests for the function "increaseLiquidity" of contract "WrappedAerodromeAM".
 */
contract IncreaseLiquidity_WrappedAerodromeAM_Fuzz_Test is WrappedAerodromeAM_Fuzz_Test {
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

    function testFuzz_Revert_increaseLiquidity_ZeroAmount(uint96 positionId) public {
        // The stake function should revert when trying to stake 0 amount.
        vm.expectRevert(WrappedAerodromeAM.ZeroAmount.selector);
        wrappedAerodromeAM.increaseLiquidity(positionId, 0);
    }

    function testFuzz_Revert_increaseLiquidity_NotOwner(
        address owner,
        address randomAddress,
        uint128 amount,
        uint96 positionId
    ) public canReceiveERC721(owner) {
        // Given : Amount is greater than zero
        amount = uint128(bound(amount, 1, type(uint128).max));

        // And : positionId is greater than 0
        positionId = uint96(bound(positionId, 1, type(uint96).max));

        // And : Owner of positionId is not the randomAddress
        vm.assume(owner != randomAddress);
        wrappedAerodromeAM.setOwnerOf(owner, positionId);

        // When : Calling Stake
        // Then : The function should revert as the randomAddress is not the owner of the positionId.
        vm.startPrank(randomAddress);
        vm.expectRevert(WrappedAerodromeAM.NotOwner.selector);
        wrappedAerodromeAM.increaseLiquidity(positionId, amount);
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
        // Given : Valid aeroPool
        aeroPool = createPoolAerodrome(address(asset0), address(asset1), stable);
        vm.assume(owner != address(aeroPool));
        vm.assume(owner != aeroPool.poolFees());

        // And: Valid state.
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);

        // And: Amount is greater than zero.
        vm.assume(poolState.totalWrapped < type(uint128).max);
        amount = uint128(bound(amount, 1, type(uint128).max - poolState.totalWrapped));

        // And: State is persisted.
        setAMState(aeroPool, positionId, poolState, positionState);
        aeroPool.setClaimables(address(wrappedAerodromeAM), fee0, fee1);
        deal(address(aeroPool), owner, amount, true);
        deal(aeroPool.token0(), aeroPool.poolFees(), fee0, true);
        deal(aeroPool.token1(), aeroPool.poolFees(), fee1, true);
        wrappedAerodromeAM.setOwnerOf(owner, positionId);

        // When :  A user is increasing liquidity via the Staking Module
        vm.startPrank(owner);
        aeroPool.approve(address(wrappedAerodromeAM), amount);
        vm.expectEmit();
        emit WrappedAerodromeAM.LiquidityIncreased(positionId, address(aeroPool), amount);
        wrappedAerodromeAM.increaseLiquidity(positionId, amount);

        // Then : Assets should have been transferred to the Staking Module
        assertEq(aeroPool.balanceOf(address(wrappedAerodromeAM)), poolState.totalWrapped + amount);
        assertEq(ERC20(aeroPool.token0()).balanceOf(address(wrappedAerodromeAM)), fee0);
        assertEq(ERC20(aeroPool.token1()).balanceOf(address(wrappedAerodromeAM)), fee1);

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
        assertEq(positionState_.pool, address(aeroPool));

        // And : Asset values should be updated correctly
        WrappedAerodromeAM.PoolState memory poolState_;
        (poolState_.fee0PerLiquidity, poolState_.fee1PerLiquidity, poolState_.totalWrapped) =
            wrappedAerodromeAM.poolState(address(aeroPool));

        assertEq(poolState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, poolState.totalWrapped + amount);
    }
}
