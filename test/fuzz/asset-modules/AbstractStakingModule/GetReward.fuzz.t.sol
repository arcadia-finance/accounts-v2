/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test } from "./_AbstractStakingModule.fuzz.t.sol";

import { AbstractStakingModule } from "../../../../src/asset-modules/staking-module/AbstractStakingModule.sol";
import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "getReward" of contract "AbstractStakingModule".
 */
contract GetReward_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
    using FixedPointMathLib for uint256;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_getReward_ZeroReward(
        uint256 id,
        address account,
        uint256 previousRewardBalance,
        uint128 rewardPerTokenStored,
        uint128 accountBalance
    ) public {
        // Given : previousRewardBalance > 0, since we are claiming the rewards of the external staking contract via getReward() we have to validate that previousRewardBalance is set to 0 after. actualRewardBalance should be equal to previousRewardBalance, as account should not earn over that period.
        vm.assume(previousRewardBalance > 0);
        stakingModule.setPreviousRewardsBalance(id, previousRewardBalance);
        stakingModule.setActualRewardBalance(id, previousRewardBalance);

        // Given : rewardPerTokenStored should be equal to userRewardPerTokenPaid (= no reward earned for Account).
        stakingModule.setRewardPerTokenStored(id, rewardPerTokenStored);
        stakingModule.setUserRewardPerTokenPaid(id, rewardPerTokenStored, account);

        // Given : Account has a non-zero balance.
        vm.assume(accountBalance > 0);
        stakingModule.setBalanceOfAccountForId(id, accountBalance, account);
        stakingModule.setTotalSupply(id, accountBalance);

        // When : Account calls getReward().
        vm.prank(account);
        stakingModule.getReward(id);

        // Then : previousRewardBalance and rewards of Account should be 0.
        assertEq(stakingModule.previousRewardsBalance(id), 0);
        assertEq(stakingModule.rewards(id, account), 0);
    }

    function testFuzz_Success_getReward_RewardGreaterThanZero(
        address account,
        AbstractStakingModuleStateForId memory moduleState,
        uint128 rewardIncrease
    ) public {
        // Given : id = 1
        uint256 id = 1;

        // Given : Valid state
        AbstractStakingModuleStateForId memory moduleState_ = setStakingModuleState(moduleState, id, account);

        // Given : Add a staking token + reward token pair
        addStakingTokens(1);

        // Given : Account has a positive balance
        vm.assume(stakingModule.balanceOf(account, id) > 0);

        // Given : Actual rewards from external staking contract are > previous claimable rewards. Thus rewardIncrease > 0.
        vm.assume(moduleState_.previousRewardBalance < type(uint128).max);
        rewardIncrease = uint128(bound(rewardIncrease, 1, type(uint128).max - moduleState_.previousRewardBalance));
        stakingModule.setActualRewardBalance(id, moduleState_.previousRewardBalance + rewardIncrease);

        // Given : The claim function on the external staking contract is not implemented, thus we fund the stakingModule with reward tokens that should be transferred.
        uint256 earned = stakingModule.earnedByAccount(id, account);
        mintTokenTo(address(stakingModule.rewardToken(id)), address(stakingModule), earned);

        // When : Account calls getReward()
        vm.startPrank(account);
        vm.expectEmit();
        emit AbstractStakingModule.RewardPaid(account, id, earned);
        stakingModule.getReward(id);
        vm.stopPrank();

        // Then : Account should have received the reward tokens.
        assertEq(earned, stakingModule.rewardToken(id).balanceOf(account));
        assertEq(stakingModule.rewards(id, account), 0);
    }
}
