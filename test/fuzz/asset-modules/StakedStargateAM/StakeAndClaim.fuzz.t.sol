/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { StakedStargateAM_Fuzz_Test } from "./_StakedStargateAM.fuzz.t.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";

/**
 * @notice Fuzz tests for the function "_stakeAndClaim" of contract "StakedStargateAM".
 */
contract StakeAndClaim_StakedStargateAM_Fuzz_Test is StakedStargateAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedStargateAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_success_stakeAndClaim(uint256 amount, uint256 pid) public {
        // Given : Random Stargate pool address.
        address poolLpToken = address(new ERC20Mock("stakingToken", "STK", 0));

        // And: Tokens are transfered directly to the AM (transferFrom happens in external stake() and is covered by our testing of the staking module).
        deal(poolLpToken, address(stakedStargateAM), amount, true);

        // And : Pool token is set for specific pool id in the LPStaking contract.
        lpStakingTimeMock.setInfoForPoolId(pid, 0, poolLpToken);

        // And : AssetToPoolId mapping is set.
        stakedStargateAM.setAssetToPoolId(poolLpToken, pid);

        // When : Calling the internal _stakeAndClaim function.
        stakedStargateAM.stake(poolLpToken, amount);

        // Then : The LP tokens should have been transferred to the LPStakingContract.
        assertEq(ERC20Mock(poolLpToken).balanceOf(address(stakedStargateAM)), 0);
        assertEq(ERC20Mock(poolLpToken).balanceOf(address(lpStakingTimeMock)), amount);
    }
}
