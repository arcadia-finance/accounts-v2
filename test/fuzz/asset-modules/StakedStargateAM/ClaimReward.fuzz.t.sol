/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { StakedStargateAM_Fuzz_Test } from "./_StakedStargateAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_claimReward" of contract "StakedStargateAM".
 */
contract ClaimReward_StakedStargateAM_Fuzz_Test is StakedStargateAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedStargateAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_claimReward(uint256 amount, uint256 pid) public {
        // Given: Random Stargate pool address.
        address poolLpToken = address(new ERC20Mock("stakingToken", "STK", 0));

        // And: LP tokens are staked in Stargate staking contract.
        deal(poolLpToken, address(lpStakingTimeMock), amount, true);

        // And: Pool token is set for specific pool id in the LPStaking contract.
        lpStakingTimeMock.setInfoForPoolId(pid, 0, poolLpToken);

        // And: AssetToPoolId mapping is set.
        stakedStargateAM.setAssetToPoolId(poolLpToken, pid);

        // When: Calling the internal _claimReward function.
        // Then: The staking contract is called with a zero withdrawal, which claims the rewards.
        vm.expectCall(address(lpStakingTimeMock), abi.encodeCall(lpStakingTimeMock.withdraw, (pid, 0)));
        stakedStargateAM.claimReward(poolLpToken);

        // And: No LP tokens are withdrawn.
        assertEq(ERC20Mock(poolLpToken).balanceOf(address(stakedStargateAM)), 0);
        assertEq(ERC20Mock(poolLpToken).balanceOf(address(lpStakingTimeMock)), amount);
    }
}
