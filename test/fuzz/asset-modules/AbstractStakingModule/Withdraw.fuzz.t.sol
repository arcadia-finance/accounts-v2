/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, StakingModule, ERC20Mock } from "./_AbstractStakingModule.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "withdraw" of contract "StakingModule".
 */
contract Withdraw_AbstractAbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
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

    function testFuzz_Revert_Withdraw_ZeroAmount(uint256 id) public {
        // Given : Amount is 0.
        uint128 amount = 0;

        // When : Trying to withdraw zero amount.
        // Then : It should revert.
        vm.expectRevert(StakingModule.ZeroAmount.selector);
        stakingModule.withdraw(id, amount);
    }

    function testFuzz_Success_Withdraw(
        address account,
        StakingModuleStateForId memory moduleState,
        uint8 underlyingTokenDecimals,
        uint8 rewardTokenDecimals
    ) public {
        // Given : account != zero address
        vm.assume(account != address(0));

        // Given : id = 2
        uint256 id = 2;

        // Given : Valid state
        StakingModuleStateForId memory moduleState_ = setStakingModuleState(moduleState, id, account);

        // Given : Add a staking token + reward token pairs
        (address[] memory underlyingTokens, address[] memory rewardTokens) =
            addStakingTokens(2, underlyingTokenDecimals, rewardTokenDecimals);

        // Given : Account has a positive balance
        vm.assume(stakingModule.balanceOf(account, id) > 0);

        // Given : transfer underlyingToken and rewardToken to stakingModule, as _withdraw and _claimReward are not implemented on external staking contract.
        address[] memory tokens = new address[](2);
        tokens[0] = underlyingTokens[1];
        tokens[1] = rewardTokens[1];

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = moduleState_.accountBalance;
        uint256 currentRewardAccount = stakingModule.rewardOf(account, id);
        amounts[1] = currentRewardAccount;

        mintERC20TokensTo(tokens, address(stakingModule), amounts);

        // When : Account withdraws from stakingModule
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.Withdrawn(account, id, moduleState_.accountBalance);
        stakingModule.withdraw(id, moduleState_.accountBalance);
        vm.stopPrank();

        // Then : Account should get the staking and reward tokens.
        assertEq(ERC20Mock(tokens[0]).balanceOf(account), moduleState_.accountBalance);
        assertEq(ERC20Mock(tokens[1]).balanceOf(account), currentRewardAccount);
        assertEq(stakingModule.balanceOf(account, id), 0);
    }

    function testFuzz_Success_Withdraw_ValidAccountingFlow() public {
        // Given : 2 actors and initial staking token amounts
        address user1 = address(0x1);
        address user2 = address(0x2);
        uint128 user1InitBalance = uint128(1_000_000 * (10 ** Constants.stableDecimals));
        uint128 user2InitBalance = uint128(4_000_000 * (10 ** Constants.stableDecimals));

        // Given : Fund both users with amount of underlyingTokens
        address underlyingToken = address(mockERC20.stable1);
        address rewardToken = address(mockERC20.token1);
        mintERC20TokenTo(underlyingToken, user1, user1InitBalance);
        mintERC20TokenTo(underlyingToken, user2, user2InitBalance);

        // Given : Add underlyingToken and rewardToken to stakingModule
        stakingModule.addNewStakingToken(underlyingToken, rewardToken);

        // Given : Both users stake in the stakingModule
        approveERC20TokenFor(underlyingToken, address(stakingModule), user1InitBalance, user1);
        approveERC20TokenFor(underlyingToken, address(stakingModule), user2InitBalance, user2);

        vm.prank(user1);
        stakingModule.stake(1, user1InitBalance);
        vm.prank(user2);
        stakingModule.stake(1, user2InitBalance);

        // Given : Mock rewards
        uint128 rewardAmount1 = uint128(1_000_000 * (10 ** Constants.tokenDecimals));
        stakingModule.setActualRewardBalance(1, rewardAmount1);
        mintERC20TokenTo(rewardToken, address(stakingModule), rewardAmount1);

        // When : User1 claims rewards
        // Then : He should receive 1/5 of the rewardAmount1
        vm.prank(user1);
        stakingModule.claimReward(1);

        assertEq(mockERC20.token1.balanceOf(user1), rewardAmount1 / 5);

        // Given : User 1 stakes additional tokens and stakes
        uint128 user1AddedBalance = uint128(3_000_000 * (10 ** Constants.stableDecimals));
        mintERC20TokenTo(underlyingToken, user1, user1AddedBalance);
        approveERC20TokenFor(underlyingToken, address(stakingModule), user1AddedBalance, user1);

        vm.prank(user1);
        stakingModule.stake(1, user1AddedBalance);

        // Given : Add 1 mio more rewards
        uint128 rewardAmount2 = uint128(1_000_000 * (10 ** Constants.tokenDecimals));
        stakingModule.setActualRewardBalance(1, rewardAmount2);
        mintERC20TokenTo(rewardToken, address(stakingModule), rewardAmount2);

        // Given : A third user stakes while there is no reward increase (this shouldn't accrue rewards for him and not impact other user rewards)
        address user3 = address(0x3);
        mintERC20TokenTo(underlyingToken, user3, user1AddedBalance);
        approveERC20TokenFor(underlyingToken, address(stakingModule), user1AddedBalance, user3);

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
        stakingModule.claimReward(1);

        assertEq(mockERC20.token1.balanceOf(user3), 0);
    }
}
