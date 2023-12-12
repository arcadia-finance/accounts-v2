/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, StakingModule } from "./_AbstractStakingModule.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "claimReward" of contract "StakingModule".
 */
contract ClaimReward_AbstractAbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
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

    function testFuzz_Success_claimReward_ZeroReward(
        uint256 id,
        address account,
        uint128 lastRewardGlobal,
        uint128 lastRewardPerTokenGlobal,
        uint128 accountBalance
    ) public {
        // Given : lastRewardGlobal > 0, since we are claiming the rewards of the external staking contract via claimReward() we have to validate that lastRewardGlobal is set to 0 after. currentRewardGlobal should be equal to lastRewardGlobal, as account should not earn over that period.
        vm.assume(lastRewardGlobal > 0);
        stakingModule.setLastRewardGlobal(id, lastRewardGlobal);
        stakingModule.setActualRewardBalance(id, lastRewardGlobal);

        // Given : lastRewardPerTokenGlobal should be equal to lastRewardPerTokenAccount (= no reward currentRewardAccount for Account).
        stakingModule.setLastRewardPerTokenGlobal(id, lastRewardPerTokenGlobal);
        stakingModule.setLastRewardPerTokenAccount(id, lastRewardPerTokenGlobal, account);

        // Given : Account has a non-zero balance.
        vm.assume(accountBalance > 0);
        stakingModule.setBalanceOf(id, accountBalance, account);
        stakingModule.setTotalSupply(id, accountBalance);

        // When : Account calls claimReward().
        vm.prank(account);
        stakingModule.claimReward(id);

        // Then : lastRewardGlobal and rewards of Account should be 0.
        (, uint128 lastRewardsGlobal_,) = stakingModule.tokenState(id);
        assertEq(lastRewardsGlobal_, 0);
        (, uint128 lastRewardAccount_) = stakingModule.accountState(account, id);
        assertEq(lastRewardAccount_, 0);
    }

    function testFuzz_Success_claimReward_RewardGreaterThanZero(
        address account,
        StakingModuleStateForId memory moduleState,
        uint128 rewardIncrease,
        uint8 underlyingTokenDecimals,
        uint8 rewardTokenDecimals
    ) public {
        // Given : account != zero address
        vm.assume(account != address(0));

        // Given : id = 1
        uint256 id = 1;

        // Given : Valid state
        StakingModuleStateForId memory moduleState_ = setStakingModuleState(moduleState, id, account);

        // Given : Add a staking token + reward token pair
        addStakingTokens(1, underlyingTokenDecimals, rewardTokenDecimals);

        // Given : Account has a positive balance
        vm.assume(stakingModule.balanceOf(account, id) > 0);

        // Given : Actual rewards from external staking contract are > previous claimable rewards. Thus rewardIncrease > 0.
        vm.assume(moduleState_.lastRewardGlobal < type(uint128).max);
        rewardIncrease = uint128(bound(rewardIncrease, 1, type(uint128).max - moduleState_.lastRewardGlobal));
        stakingModule.setActualRewardBalance(id, moduleState_.lastRewardGlobal + rewardIncrease);

        // Given : The claim function on the external staking contract is not implemented, thus we fund the stakingModule with reward tokens that should be transferred.
        uint256 currentRewardAccount = stakingModule.rewardOf(account, id);
        mintERC20TokenTo(address(stakingModule.rewardToken(id)), address(stakingModule), currentRewardAccount);

        // Given : currentRewardAccount > 0, for very small reward increase and high balances, it could return zero.
        vm.assume(currentRewardAccount > 0);

        // When : Account calls claimReward()
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.RewardPaid(account, id, currentRewardAccount);
        stakingModule.claimReward(id);
        vm.stopPrank();

        // Then : Account should have received the reward tokens.
        assertEq(currentRewardAccount, stakingModule.rewardToken(id).balanceOf(account));
        (, currentRewardAccount) = stakingModule.accountState(account, id);
        assertEq(currentRewardAccount, 0);
    }
}
