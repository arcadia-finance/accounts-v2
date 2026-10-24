/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ILeafVoter } from "../../../utils/fixtures/metadex03/interfaces/ILeafVoter.sol";
import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "claimDeferredRewards" of contract "StakedMetadex03CLAM".
 */
contract ClaimDeferredRewards_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
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

    function testFuzz_Revert_claimDeferredRewards_GaugeNotValid(address gauge_, address sender, int24 tick) public {
        // Given: A gauge on a pool.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);

        // And: The gauge that is claimed from was not deployed by the GaugeFactory.
        vm.assume(gauge_ != address(gauge));

        // When: The sender claims the deferred emissions.
        // Then: It reverts.
        vm.prank(sender);
        vm.expectRevert(StakedSlipstreamAM.GaugeNotValid.selector);
        stakedMetadex03CLAM.claimDeferredRewards(gauge_);
    }

    function testFuzz_Success_claimDeferredRewards_NothingDeferred(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        uint256 donation,
        int24 tick,
        address sender,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A staked position, of which nothing was deferred.
        emissions = bound(emissions, 0, MAX_BASE_RATE);
        _initStakedPositionWithEarned(position, emissions, tick);
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), 0);

        // And: Reward tokens reached the Asset Module outside a claim.
        donation = bound(donation, 1, type(uint128).max);
        deal(rewardToken, address(stakedMetadex03CLAM), donation);

        // When: The sender claims the deferred emissions.
        vm.prank(sender);
        stakedMetadex03CLAM.claimDeferredRewards(address(gauge));

        // Then: The gauge is not called for an empty claim, and the donation stays claimable.
        assertEq(ERC20(rewardToken).balanceOf(surplusRecipient), 0);
        assertEq(stakedMetadex03CLAM.claimableSurplus(), donation);
    }

    function testFuzz_Revert_claimDeferredRewards_ChainSuspended(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick,
        address sender
    ) public {
        // Given: The gauge deferred the emissions of a burned position, over the wei rounding can take.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        assertGt(_stakeAndDeferEmissions(position, emissions, tick), 0);

        // And: The chain can no longer mint.
        setChainSuspended(true);

        // When: The sender claims the deferred emissions.
        // Then: It reverts.
        vm.prank(sender);
        vm.expectRevert(ILeafVoter.ChainNotActiveOrSunset.selector);
        stakedMetadex03CLAM.claimDeferredRewards(address(gauge));
    }

    function testFuzz_Success_claimDeferredRewards_Leaf(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        uint256 donation,
        int24 tick,
        address sender,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: The gauge deferred the emissions of a burned position, over the wei rounding can take.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        uint256 deferredEmissions = _stakeAndDeferEmissions(position, emissions, tick);
        assertGt(deferredEmissions, 0);

        // And: Reward tokens reached the Asset Module outside a claim.
        donation = bound(donation, 1, type(uint128).max);
        deal(rewardToken, address(stakedMetadex03CLAM), donation);

        // When: The sender claims the deferred emissions.
        vm.prank(sender);
        stakedMetadex03CLAM.claimDeferredRewards(address(gauge));

        // Then: The recipient received the deferred emissions, the donation stays claimable.
        assertEq(ERC20(rewardToken).balanceOf(surplusRecipient), deferredEmissions);
        assertEq(stakedMetadex03CLAM.claimableSurplus(), donation);
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_claimDeferredRewards_Root_AboveMinRedeemAmount(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick,
        address sender,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A gauge on the root chain deferred emissions that clears the redeem floor.
        _stageRoot();
        emissions = bound(emissions, MIN_REDEEM_AMOUNT + 1, MAX_BASE_RATE);
        uint256 deferredEmissions = _stakeAndDeferEmissions(position, emissions, tick);
        assertGe(deferredEmissions, MIN_REDEEM_AMOUNT);

        // When: The sender claims the deferred emissions.
        vm.prank(sender);
        stakedMetadex03CLAM.claimDeferredRewards(address(gauge));

        // Then: The ReceiptToken was redeemed for the Token, which the recipient received.
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), deferredEmissions);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03CLAM)), 0);
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_claimDeferredRewards_Root_BelowMinRedeemAmount(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick,
        address sender,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A gauge on the root chain deferred emissions that stays below the redeem floor.
        _stageRoot();
        emissions = bound(emissions, 2, MIN_REDEEM_AMOUNT - 1);
        uint256 deferredEmissions = _stakeAndDeferEmissions(position, emissions, tick);
        assertGt(deferredEmissions, 0);
        assertLt(deferredEmissions, MIN_REDEEM_AMOUNT);

        // When: The sender claims the deferred emissions.
        vm.prank(sender);
        stakedMetadex03CLAM.claimDeferredRewards(address(gauge));

        // Then: The deferred emissions are cleared but the root handler holds the sub floor total pending.
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), 0);
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), 0);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03CLAM)), 0);
    }
}
