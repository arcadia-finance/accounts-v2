/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { IMetadex03V2GaugeFactory } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2GaugeFactory.sol";
import { StakedMetadex03AM_Fuzz_Test } from "./_StakedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "WithdrawAndClaim" function of contract "StakedMetadex03AM".
 */
contract WithdrawAndClaim_StakedMetadex03AM_Fuzz_Test is StakedMetadex03AM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedMetadex03AM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_withdrawAndClaim_GaugeTapeGasLimit(uint256 lpBalance, address gaugeTape) public {
        // Given: A position staked through its own staker.
        (uint256 staked, uint256 positionId) = _stakeInGauge(lpBalance);

        // And: A gauge tape whose gas limit exceeds the gas left in the call.
        vm.assume(gaugeTape != address(0));
        setGaugeTape(address(metadex03Gauge), gaugeTape, type(uint32).max);

        // When: The Asset Module withdraws for the position.
        // Then: It reverts.
        vm.expectRevert(IMetadex03V2GaugeFactory.InsufficientGasForCall.selector);
        stakedMetadex03AM.withdrawAndClaim{ gas: 10_000_000 }(positionId, address(metadex03Pool), staked);
    }

    function testFuzz_Success_withdrawAndClaim(uint256 lpBalance, uint256 toWithdraw, uint256 emissions) public {
        // Given: A position staked through its own staker.
        (uint256 staked, uint256 positionId) = _stakeInGauge(lpBalance);
        address staker = stakedMetadex03AM.getStaker(positionId);

        // And: Add emissions to metadex03Gauge.
        emissions = bound(emissions, 1, type(uint128).max);
        addEmissionsToGauge(address(metadex03Gauge), emissions);

        // And: Let rewards accumulate.
        vm.warp(block.timestamp + 3 days);
        uint256 earned = metadex03Gauge.earned(staker);

        // And: A non-zero part of the staked balance is withdrawn.
        toWithdraw = bound(toWithdraw, 1, staked);

        // When: Withdrawing LP's of the position from the metadex03Gauge.
        stakedMetadex03AM.withdrawAndClaim(positionId, address(metadex03Pool), toWithdraw);

        // Then: The stake decreased and the LP and rewards reached the Asset Module.
        assertEq(metadex03Gauge.balanceOf(staker), staked - toWithdraw);
        assertEq(metadex03Pool.balanceOf(address(stakedMetadex03AM)), toWithdraw);
        assertEq(stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM)), earned);
    }

    function testFuzz_Success_withdrawAndClaim_ZeroClaim(uint256 lpBalance, uint256 toWithdraw) public {
        // Given: A position staked through its own staker, no emissions accrued to the gauge.
        (uint256 staked, uint256 positionId) = _stakeInGauge(lpBalance);
        address staker = stakedMetadex03AM.getStaker(positionId);

        // And: A non-zero part of the staked balance is withdrawn.
        toWithdraw = bound(toWithdraw, 1, staked);

        // When: Withdrawing LP's of the position from the metadex03Gauge.
        stakedMetadex03AM.withdrawAndClaim(positionId, address(metadex03Pool), toWithdraw);

        // Then: The stake of the staker decreased and the LP reached the Asset Module.
        assertEq(metadex03Gauge.balanceOf(staker), staked - toWithdraw);
        assertEq(metadex03Pool.balanceOf(address(stakedMetadex03AM)), toWithdraw);
        assertEq(metadex03Pool.balanceOf(staker), 0);
    }
}
