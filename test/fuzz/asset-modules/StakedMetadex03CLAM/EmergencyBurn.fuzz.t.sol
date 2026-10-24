/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC721 } from "../../../../lib/solmate/src/tokens/ERC721.sol";
import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "emergencyBurn" of contract "StakedMetadex03CLAM".
 */
// forge-lint: disable-next-item(reentrancy-no-eth,unsafe-typecast)
contract EmergencyBurn_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03CLAM_Fuzz_Test.setUp();

        deployStakedMetadex03CLAM();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_emergencyBurn_NonExistingId(uint256 assetId, address sender) public {
        // Given: The asset id is not staked, so its owner reads as the zero address.

        // And: The sender is not the zero address, which can never be a caller.
        vm.assume(sender != address(0));

        // When: The sender burns the position.
        // Then: It reverts.
        vm.prank(sender);
        vm.expectRevert(StakedSlipstreamAM.NotOwner.selector);
        stakedMetadex03CLAM.emergencyBurn(assetId);
    }

    function testFuzz_Revert_emergencyBurn_NonOwner(
        StakedSlipstreamAM.PositionState memory position,
        address nonOwner,
        int24 tick
    ) public {
        // Given: A staked position of the liquidity provider.
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);
        position = givenValidPosition(position);
        uint256 assetId = _stakePosition(position);

        // And: The sender is not the owner of the position.
        vm.assume(nonOwner != users.liquidityProvider);

        // When: The sender burns the position.
        // Then: It reverts.
        vm.prank(nonOwner);
        vm.expectRevert(StakedSlipstreamAM.NotOwner.selector);
        stakedMetadex03CLAM.emergencyBurn(assetId);
    }

    function testFuzz_Revert_emergencyBurn_EmergencyWithdrawDisabled(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) public {
        // Given: A staked position with earned emissions.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        uint256 assetId = _initStakedPositionWithEarned(position, emissions, tick);

        // And: The gauge factory disables emergency withdrawals.
        metadex03CLGaugeFactory.setEmergencyWithdrawEnabled(false);

        // When: The liquidity provider burns the position.
        // Then: It reverts.
        vm.prank(users.liquidityProvider);
        vm.expectRevert(bytes("NE"));
        stakedMetadex03CLAM.emergencyBurn(assetId);
    }

    function testFuzz_Success_emergencyBurn(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) public {
        // Given: A staked position with earned emissions.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        uint256 assetId = _initStakedPositionWithEarned(position, emissions, tick);
        assertGt(gauge.earned(address(stakedMetadex03CLAM), stakedMetadex03CLAM.asSingleton(assetId)), 0);

        // And: The gauge factory enables emergency withdrawals.
        metadex03CLGaugeFactory.setEmergencyWithdrawEnabled(true);

        // When: The liquidity provider burns the position.
        // Then: The Transfer event is emitted.
        vm.prank(users.liquidityProvider);
        vm.expectEmit(address(stakedMetadex03CLAM));
        emit ERC721.Transfer(users.liquidityProvider, address(0), assetId);
        stakedMetadex03CLAM.emergencyBurn(assetId);

        // And: The position is transferred back to the owner and the staked position is burned.
        assertEq(metadex03PositionManager.ownerOf(assetId), users.liquidityProvider);
        assertEq(stakedMetadex03CLAM.balanceOf(users.liquidityProvider), 0);

        // And: The position state is deleted.
        (int24 tickLower, int24 tickUpper, uint128 liquidity, address gauge_) =
            stakedMetadex03CLAM.positionState(assetId);
        assertEq(tickLower, 0);
        assertEq(tickUpper, 0);
        assertEq(liquidity, 0);
        assertEq(gauge_, address(0));

        // And: No reward is paid and nothing is stuck in the Asset Module.
        assertEq(ERC20(receiptToken).balanceOf(users.liquidityProvider), 0);
        assertEq(ERC20(receiptToken).balanceOf(address(stakedMetadex03CLAM)), 0);
        assertEq(token0.balanceOf(address(stakedMetadex03CLAM)), 0);
        assertEq(token1.balanceOf(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_emergencyBurn_LeafVoterReverts(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) public {
        // Given: A staked position with earned emissions.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        uint256 assetId = _initStakedPositionWithEarned(position, emissions, tick);
        assertGt(gauge.earned(address(stakedMetadex03CLAM), stakedMetadex03CLAM.asSingleton(assetId)), 0);

        // And: The gauge factory enables emergency withdrawals.
        metadex03CLGaugeFactory.setEmergencyWithdrawEnabled(true);

        // And: Every call to the LeafVoter reverts.
        vm.mockCallRevert(address(leafVoter), bytes(""), bytes(""));

        // When: The liquidity provider burns the position.
        vm.prank(users.liquidityProvider);
        stakedMetadex03CLAM.emergencyBurn(assetId);

        // Then: The position is transferred back to the owner without a reward.
        assertEq(metadex03PositionManager.ownerOf(assetId), users.liquidityProvider);
        assertEq(stakedMetadex03CLAM.balanceOf(users.liquidityProvider), 0);
        assertEq(ERC20(receiptToken).balanceOf(users.liquidityProvider), 0);
        assertEq(ERC20(receiptToken).balanceOf(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_emergencyBurn_AboveRange_LeafVoterReverts(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) public {
        // Given: A staked position with the current tick of the pool above its range.
        position.tickLower = int24(bound(position.tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 2));
        position.tickUpper = int24(bound(position.tickUpper, position.tickLower + 1, TickMath.MAX_TICK - 1));
        position = givenValidPosition(position, 1);
        tick = int24(bound(tick, position.tickUpper, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);
        uint256 assetId = _stakePosition(position);
        uint128 stakedLiquidity = pool.stakedLiquidity();

        // And: The gauge has emissions.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        addEmissionsToGauge(address(gauge), emissions);
        vm.warp(block.timestamp + 1);

        // And: The gauge factory enables emergency withdrawals.
        metadex03CLGaugeFactory.setEmergencyWithdrawEnabled(true);

        // And: Every call to the LeafVoter reverts.
        vm.mockCallRevert(address(leafVoter), bytes(""), bytes(""));

        // When: The liquidity provider burns the position.
        vm.prank(users.liquidityProvider);
        stakedMetadex03CLAM.emergencyBurn(assetId);

        // Then: The position is transferred back to the owner.
        assertEq(metadex03PositionManager.ownerOf(assetId), users.liquidityProvider);
        assertEq(stakedMetadex03CLAM.balanceOf(users.liquidityProvider), 0);

        // And: The staked liquidity of the pool is unchanged.
        assertEq(pool.stakedLiquidity(), stakedLiquidity);

        // And: The position state is deleted.
        (int24 tickLower, int24 tickUpper, uint128 liquidity, address gauge_) =
            stakedMetadex03CLAM.positionState(assetId);
        assertEq(tickLower, 0);
        assertEq(tickUpper, 0);
        assertEq(liquidity, 0);
        assertEq(gauge_, address(0));

        // And: No reward is paid and nothing is stuck in the Asset Module.
        assertEq(ERC20(receiptToken).balanceOf(users.liquidityProvider), 0);
        assertEq(ERC20(receiptToken).balanceOf(address(stakedMetadex03CLAM)), 0);
        assertEq(token0.balanceOf(address(stakedMetadex03CLAM)), 0);
        assertEq(token1.balanceOf(address(stakedMetadex03CLAM)), 0);
    }
}
