/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "_claimReward" of contract "StakedMetadex03CLAM".
 */
contract ClaimReward_Gauge_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
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

    function testFuzz_Success_claimReward_ZeroDeferredRewards_NonZeroReward(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A staked position whose emissions exceed the wei its share can round away.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        uint256 assetId = _initStakedPositionWithEarned(position, emissions, tick);
        uint256 rewardsExpected = stakedMetadex03CLAM.rewardOf(assetId);
        assertGt(rewardsExpected, 0);

        // And: The gauge deferred nothing.
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), 0);

        // When: Calling _claimReward().
        stakedMetadex03CLAM.claimReward(address(gauge), assetId);

        // Then: The Asset Module holds the claimed emissions and the recipient received nothing.
        assertEq(ERC20(rewardToken).balanceOf(address(stakedMetadex03CLAM)), rewardsExpected);
        assertEq(ERC20(rewardToken).balanceOf(surplusRecipient), 0);
    }

    function testFuzz_Success_claimReward_ZeroDeferredRewards_ZeroReward(
        StakedSlipstreamAM.PositionState memory position,
        int24 tick,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A staked position, of which no emissions accrued.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);
        position = givenValidPosition(position, 1);
        uint256 assetId = _stakePosition(position);

        // When: Calling _claimReward().
        stakedMetadex03CLAM.claimReward(address(gauge), assetId);

        // Then: Neither the Asset Module nor the recipient received anything.
        assertEq(ERC20(rewardToken).balanceOf(address(stakedMetadex03CLAM)), 0);
        assertEq(ERC20(rewardToken).balanceOf(surplusRecipient), 0);
    }

    function testFuzz_Success_claimReward_NonZeroDeferredRewards_ZeroReward(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: The gauge deferred the emissions of a burned position.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        position = _givenPositionWithRoomAbove(position);
        uint256 deferredEmissions = _stakeAndDeferEmissions(position, emissions, tick);
        assertGt(deferredEmissions, 0);

        // And: A position is staked above the current tick, earning nothing of its own.
        uint256 assetId = _stakeIdlePositionAbove(position);

        // When: Calling _claimReward().
        stakedMetadex03CLAM.claimReward(address(gauge), assetId);

        // Then: The recipient received the deferred emissions and the Asset Module holds nothing.
        assertEq(ERC20(rewardToken).balanceOf(surplusRecipient), deferredEmissions);
        assertEq(ERC20(rewardToken).balanceOf(address(stakedMetadex03CLAM)), 0);
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), 0);
    }
}
