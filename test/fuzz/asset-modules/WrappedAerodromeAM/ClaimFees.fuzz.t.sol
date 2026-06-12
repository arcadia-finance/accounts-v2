/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

/**
 * @notice Fuzz tests for the function "claimFees" of contract "WrappedAerodromeAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract ClaimFees_WrappedAerodromeAM_Fuzz_Test is WrappedAerodromeAM_Fuzz_Test {
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

    function testFuzz_Revert_claimFees_NonExistingPosition(uint256 positionId, address randomAddress) public {
        // Given : randomAddress is not the zero address.
        vm.assume(randomAddress != address(0));

        // When : Trying to claim for non existing position.
        // Then : It should revert.
        vm.prank(randomAddress);
        vm.expectRevert(WrappedAerodromeAM.NotOwner.selector);
        wrappedAerodromeAM.claimFees(positionId);
    }

    function testFuzz_Revert_claimFees_NotOwner(
        bool stable,
        address owner,
        address randomAddress,
        uint96 positionId,
        WrappedAerodromeAM.PositionState memory positionState,
        WrappedAerodromeAM.PoolState memory poolState
    ) public canReceiveERC721(owner) {
        // Given : Owner of positionId is not the randomAddress
        vm.assume(owner != randomAddress);

        // And : Valid aeroPool
        aeroPool = createPoolAerodrome(address(asset0), address(asset1), stable);
        vm.assume(owner != address(aeroPool));
        vm.assume(owner != aeroPool.poolFees());

        // And: State is persisted.
        setAMState(aeroPool, positionId, poolState, positionState);
        wrappedAerodromeAM.mintIdTo(owner, positionId);

        // When : Trying to claim fees for a position not owned by the caller.
        // Then : It should revert.
        vm.prank(randomAddress);
        vm.expectRevert(WrappedAerodromeAM.NotOwner.selector);
        wrappedAerodromeAM.claimFees(positionId);
    }

    function testFuzz_Success_claimFees(
        bool stable,
        address owner,
        uint96 positionId,
        uint256 fee0,
        uint256 fee1,
        WrappedAerodromeAM.PositionState memory positionState,
        WrappedAerodromeAM.PoolState memory poolState
    ) public canReceiveERC721(owner) {
        // Given : Valid aeroPool
        aeroPool = createPoolAerodrome(address(asset0), address(asset1), stable);
        vm.assume(owner != address(aeroPool));
        vm.assume(owner != aeroPool.poolFees());

        // And: Valid state.
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);

        // And : Owner has a balance bigger as 1.
        vm.assume(positionState.amountWrapped > 1);

        // And: State is persisted.
        setAMState(aeroPool, positionId, poolState, positionState);
        aeroPool.setClaimables(address(wrappedAerodromeAM), fee0, fee1);
        deal(aeroPool.token0(), aeroPool.poolFees(), fee0, true);
        deal(aeroPool.token1(), aeroPool.poolFees(), fee1, true);
        wrappedAerodromeAM.mintIdTo(owner, positionId);

        {
            // And: AM holds sufficient funds from past fees.
            (uint256 fee0_, uint256 fee1_) = wrappedAerodromeAM.feesOf(positionId);
            deal(aeroPool.token0(), address(wrappedAerodromeAM), fee0_, true);
            deal(aeroPool.token1(), address(wrappedAerodromeAM), fee1_, true);

            // When : Account calls claimFees()
            vm.startPrank(owner);
            vm.expectEmit();
            emit WrappedAerodromeAM.FeesPaid(positionId, uint128(fee0_), uint128(fee1_));
            (uint256 _fee0_, uint256 _fee1_) = wrappedAerodromeAM.claimFees(positionId);
            vm.stopPrank();

            // Then : Claimed rewards are returned.
            assertEq(fee0_, _fee0_);
            assertEq(fee1_, _fee1_);

            // And : Owner should get the fees but no aeroPool tokens.
            assertEq(aeroPool.balanceOf(owner), 0);
            assertEq(ERC20(aeroPool.token0()).balanceOf(owner), fee0_);
            assertEq(ERC20(aeroPool.token1()).balanceOf(owner), fee1_);
        }

        // And: Position state should be updated correctly.
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
        assertEq(positionState_.amountWrapped, positionState.amountWrapped);
        assertEq(positionState_.pool, address(aeroPool));

        // And : Asset values should be updated correctly
        WrappedAerodromeAM.PoolState memory poolState_;
        (poolState_.fee0PerLiquidity, poolState_.fee1PerLiquidity, poolState_.totalWrapped) =
            wrappedAerodromeAM.poolState(address(aeroPool));

        assertEq(poolState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, poolState.totalWrapped);
    }
}
