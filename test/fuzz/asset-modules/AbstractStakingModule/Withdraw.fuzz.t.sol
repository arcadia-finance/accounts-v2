/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, ERC20Mock, StakingModuleErrors } from "./_AbstractStakingModule.fuzz.t.sol";

import { AbstractStakingModule } from "../../../../src/asset-modules/staking-module/AbstractStakingModule.sol";
import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "withdraw" of contract "AbstractStakingModule".
 */
contract Withdraw_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
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

    function testFuzz_Revert_withdraw_Reentered(uint256 id, uint256 amount) public {
        // Given : Reentrancy guard is in locked state.
        stakingModule.setLocked(2);

        // When : A user withdraws.
        // Then : It should revert.
        vm.expectRevert(StakingModuleErrors.NoReentry.selector);
        stakingModule.withdraw(id, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_Withdraw_ZeroAmount(uint256 id) public {
        // Given : Amount is 0.
        uint256 amount = 0;

        // When : Trying to withdraw zero amount.
        // Then : It should revert.
        vm.expectRevert(StakingModuleErrors.AmountIsZero.selector);
        stakingModule.withdraw(id, amount);
    }

    function testFuzz_Success_Withdraw(
        address account,
        AbstractStakingModuleStateForId memory moduleState,
        uint8 stakingTokenDecimals,
        uint8 rewardTokenDecimals
    ) public {
        // Given : id = 2
        uint256 id = 2;

        // Given : Valid state
        AbstractStakingModuleStateForId memory moduleState_ = setStakingModuleState(moduleState, id, account);

        // Given : Add a staking token + reward token pairs
        (address[] memory stakingTokens, address[] memory rewardTokens) =
            addStakingTokens(2, stakingTokenDecimals, rewardTokenDecimals);

        // Given : Account has a positive balance
        vm.assume(stakingModule.balanceOf(account, id) > 0);

        // Given : transfer stakingToken and rewardToken to stakingModule, as _withdraw and _claimRewards are not implemented on external staking contract.
        address[] memory tokens = new address[](2);
        tokens[0] = stakingTokens[1];
        tokens[1] = rewardTokens[1];

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = moduleState_.userBalance;
        uint256 earnedRewards = stakingModule.earnedByAccount(id, account);
        amounts[1] = earnedRewards;

        mintERC20TokensTo(tokens, address(stakingModule), amounts);

        // When : Account withdraws from stakingModule
        vm.startPrank(account);
        vm.expectEmit();
        emit AbstractStakingModule.Withdrawn(account, id, moduleState_.userBalance);
        stakingModule.withdraw(id, moduleState_.userBalance);
        vm.stopPrank();

        // Then : Account should get the staking and reward tokens.
        assertEq(ERC20Mock(tokens[0]).balanceOf(account), moduleState_.userBalance);
        assertEq(ERC20Mock(tokens[1]).balanceOf(account), earnedRewards);
        assertEq(stakingModule.balanceOf(account, id), 0);
    }

    function testFuzz_Success_Withdraw_ValidAccountingFlow() public {
        // Given : 2 actors and initial staking token amounts
        address user1 = address(0x1);
        address user2 = address(0x2);
        uint256 user1InitBalance = 1_000_000 * (10 ** Constants.stableDecimals);
        uint256 user2InitBalance = 4_000_000 * (10 ** Constants.stableDecimals);

        // Given : Fund both users with amount of stakingTokens
        address stakingToken = address(mockERC20.stable1);
        address rewardToken = address(mockERC20.token1);
        mintERC20TokenTo(stakingToken, user1, user1InitBalance);
        mintERC20TokenTo(stakingToken, user2, user2InitBalance);

        // Given : Add stakingToken and rewardToken to stakingModule
        stakingModule.addNewStakingToken(stakingToken, rewardToken);

        // Given : Both users stake in the stakingModule
        approveERC20TokenFor(stakingToken, address(stakingModule), user1InitBalance, user1);
        approveERC20TokenFor(stakingToken, address(stakingModule), user2InitBalance, user2);

        vm.prank(user1);
        stakingModule.stake(1, user1InitBalance);
        vm.prank(user2);
        stakingModule.stake(1, user2InitBalance);

        // Given : Mock rewards
        uint256 rewardAmount1 = 1_000_000 * (10 ** Constants.tokenDecimals);
        stakingModule.setActualRewardBalance(1, rewardAmount1);
        mintERC20TokenTo(rewardToken, address(stakingModule), rewardAmount1);

        // When : User1 claims rewards
        // Then : He should receive 1/5 of the rewardAmount1
        vm.prank(user1);
        stakingModule.getReward(1);

        assertEq(mockERC20.token1.balanceOf(user1), rewardAmount1 / 5);

        // Given : User 1 stakes additional tokens and stakes
        uint256 user1AddedBalance = 3_000_000 * (10 ** Constants.stableDecimals);
        mintERC20TokenTo(stakingToken, user1, user1AddedBalance);
        approveERC20TokenFor(stakingToken, address(stakingModule), user1AddedBalance, user1);

        vm.prank(user1);
        stakingModule.stake(1, user1AddedBalance);

        // Given : Add 1 mio more rewards
        uint256 rewardAmount2 = 1_000_000 * (10 ** Constants.tokenDecimals);
        stakingModule.setActualRewardBalance(1, rewardAmount2);
        mintERC20TokenTo(rewardToken, address(stakingModule), rewardAmount2);

        // Given : A third user stakes while there is no reward increase (this shouldn't accrue rewards for him and not impact other user rewards)
        address user3 = address(0x3);
        mintERC20TokenTo(stakingToken, user3, user1AddedBalance);
        approveERC20TokenFor(stakingToken, address(stakingModule), user1AddedBalance, user3);

        vm.prank(user3);
        stakingModule.stake(1, user1AddedBalance);

        // When : User1 withdraws
        // Then : He should receive half of rewardAmount2
        vm.prank(user1);
        stakingModule.withdraw(1, user1InitBalance + user1AddedBalance);

        assertEq(mockERC20.token1.balanceOf(user1), (rewardAmount1 / 5) + (rewardAmount2 / 2));
        assertEq(mockERC20.stable1.balanceOf(user1), user1InitBalance + user1AddedBalance);

        // When : User2 withdraws
        // Then : He should receive 4/5 of rewards1 + 1/2 of rewards2
        vm.prank(user2);
        stakingModule.withdraw(1, user2InitBalance);

        assertEq(mockERC20.token1.balanceOf(user2), ((4 * rewardAmount1) / 5) + (rewardAmount2 / 2));
        assertEq(mockERC20.stable1.balanceOf(user2), user2InitBalance);

        // When : User2 calls getRewards()
        // Then : He should not have accrued any rewards
        vm.prank(user3);
        stakingModule.getReward(1);

        assertEq(mockERC20.token1.balanceOf(user3), 0);
    }
}
