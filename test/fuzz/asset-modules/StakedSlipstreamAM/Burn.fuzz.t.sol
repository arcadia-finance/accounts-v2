/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC721 } from "../../../../lib/solmate/src/tokens/ERC721.sol";
import { FixedPoint128 } from "../../../../src/asset-modules/UniswapV3/libraries/FixedPoint128.sol";
import { FullMath } from "../../../../src/asset-modules/UniswapV3/libraries/FullMath.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "burn" of contract "StakedSlipstreamAM".
 */
contract Burn_StakedSlipstreamAM_Fuzz_Test is StakedSlipstreamAM_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedSlipstreamAM_Fuzz_Test.setUp();

        deployStakedSlipstreamAM();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_burn_NonExistingId(uint256 assetId) public {
        // Given: assetId is not staked.

        // When: sender claims rewards.
        // Then: Transaction reverts.
        vm.expectRevert(StakedSlipstreamAM.NotOwner.selector);
        stakedSlipstreamAM.burn(assetId);
    }

    function testFuzz_Revert_burn_NonOwner(StakedSlipstreamAM.PositionState memory position, address nonOwner) public {
        // Given: sender is not the owner.
        vm.assume(nonOwner != users.liquidityProvider);

        // And: assetId is minted.
        deployAndAddGauge();
        position = givenValidPosition(position);
        uint256 assetId = addLiquidity(position);

        // And: Position is staked.
        vm.startPrank(users.liquidityProvider);
        slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);
        stakedSlipstreamAM.mint(assetId);
        vm.stopPrank();

        // When: sender claims rewards.
        // Then: Transaction reverts.
        vm.prank(nonOwner);
        vm.expectRevert(StakedSlipstreamAM.NotOwner.selector);
        stakedSlipstreamAM.burn(assetId);
    }

    function testFuzz_Success_burn_NonZeroReward(
        StakedSlipstreamAM.PositionState memory position,
        uint256 rewardGrowthGlobalX128Last,
        uint256 rewardGrowthGlobalX128Current,
        int24 tick
    ) public {
        // Given : a valid position.
        position = givenValidPosition(position, 1);

        // And : the current tick of the pool is in range (can't be equal to tickUpper, but can be equal to tickLower).
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        deployAndAddGauge(tick);

        // Given : An initial rewardGrowthGlobalX128.
        stdstore.target(address(pool)).sig(pool.rewardGrowthGlobalX128.selector).checked_write(
            rewardGrowthGlobalX128Last
        );

        // And : assetId is minted.
        uint256 assetId = addLiquidity(position);

        // And: Position is staked.
        vm.startPrank(users.liquidityProvider);
        slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);
        stakedSlipstreamAM.mint(assetId);
        vm.stopPrank();

        // And : Rewards are earned.
        vm.warp(block.timestamp + 1);
        deal(AERO, address(gauge), type(uint256).max, true);
        stdstore.target(address(pool)).sig(pool.rewardReserve.selector).checked_write(type(uint256).max);
        stdstore.target(address(pool)).sig(pool.rewardGrowthGlobalX128.selector).checked_write(
            rewardGrowthGlobalX128Current
        );

        // And : Rewards amount is not zero.
        uint256 rewardGrowthInsideX128;
        unchecked {
            rewardGrowthInsideX128 = rewardGrowthGlobalX128Current - rewardGrowthGlobalX128Last;
        }
        uint256 liquidity = getActualLiquidity(position);
        uint256 rewardsExpected = FullMath.mulDiv(rewardGrowthInsideX128, liquidity, FixedPoint128.Q128);
        vm.assume(rewardsExpected > 0);

        // When : Owner calls burn.
        // Then : correct events are emitted.
        vm.prank(users.liquidityProvider);
        vm.expectEmit(address(stakedSlipstreamAM));
        emit ERC721.Transfer(users.liquidityProvider, address(0), assetId);
        vm.expectEmit(address(stakedSlipstreamAM));
        emit StakedSlipstreamAM.RewardPaid(assetId, AERO, uint128(rewardsExpected));
        uint256 rewards = stakedSlipstreamAM.burn(assetId);

        // Then : The correct rewards amount is returned.
        assertEq(rewards, rewardsExpected);

        // And: Balance of owner increased.
        assertEq(ERC20(AERO).balanceOf(users.liquidityProvider), rewardsExpected);

        // And: Asset is transferred back to the owner.
        assertEq(slipstreamPositionManager.ownerOf(assetId), users.liquidityProvider);
    }

    function testFuzz_Success_burn_ZeroReward(StakedSlipstreamAM.PositionState memory position) public {
        // Given : a valid position.
        position = givenValidPosition(position, 1);
        deployAndAddGauge();

        // And : assetId is minted.
        uint256 assetId = addLiquidity(position);

        // And: Position is staked.
        vm.startPrank(users.liquidityProvider);
        slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);
        stakedSlipstreamAM.mint(assetId);
        vm.stopPrank();

        // When : burn is called.
        // Then : correct event is emitted.
        vm.prank(users.liquidityProvider);
        vm.expectEmit(address(stakedSlipstreamAM));
        emit ERC721.Transfer(users.liquidityProvider, address(0), assetId);
        uint256 rewards = stakedSlipstreamAM.burn(assetId);

        // Then : The 0 rewards amount is returned.
        assertEq(rewards, 0);

        // And: Asset is transferred back to the owner.
        assertEq(slipstreamPositionManager.ownerOf(assetId), users.liquidityProvider);
    }
}
