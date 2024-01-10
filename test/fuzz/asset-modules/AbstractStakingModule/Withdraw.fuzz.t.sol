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

    function testFuzz_Revert_Withdraw_ZeroAmount(uint256 id) public {
        // Given : Amount is 0.
        uint128 amount = 0;

        // When : Trying to withdraw zero amount.
        // Then : It should revert.
        vm.expectRevert(StakingModule.ZeroAmount.selector);
        stakingModule.withdraw(id, amount);
    }

    function testFuzz_Success_Withdraw(
        uint256 tokenId,
        address account,
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint8 assetDecimals,
        uint8 rewardTokenDecimals
    ) public {
        // Given : account != zero address
        vm.assume(account != address(0));

        // Given : Add a staking token + reward token pairs
        (address[] memory assets, address[] memory rewardTokens) = addAssets(1, assetDecimals, rewardTokenDecimals);

        // Given : Valid state
        (assetState, positionState) = setStakingModuleState(assetState, positionState, assets[0], tokenId);

        // Given : ERC721 is minted to Account
        stakingModule.mint(account, tokenId);

        // Given : Account has a positive balance
        (,, uint128 amountStaked,,) = stakingModule.positionState(tokenId);
        vm.assume(amountStaked > 0);

        // Given : transfer underlyingToken and rewardToken to stakingModule, as _withdraw and _claimReward are not implemented on external staking contract.
        address[] memory tokens = new address[](2);
        tokens[0] = assets[0];
        tokens[1] = rewardTokens[0];

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = positionState.amountStaked;
        uint256 currentRewardAccount = stakingModule.rewardOf(tokenId);
        amounts[1] = currentRewardAccount;

        mintERC20TokensTo(tokens, address(stakingModule), amounts);

        // When : Account withdraws from stakingModule
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.Withdrawn(account, assets[0], positionState.amountStaked);
        stakingModule.withdraw(tokenId, positionState.amountStaked);
        vm.stopPrank();

        // Then : Account should get the staking and reward tokens.
        assertEq(ERC20Mock(tokens[0]).balanceOf(account), positionState.amountStaked);
        assertEq(ERC20Mock(tokens[1]).balanceOf(account), currentRewardAccount);
        assertEq(stakingModule.balanceOf(account), 0);
    }

    // Note : add partial withdraw

    function testFuzz_Success_Withdraw_ValidAccountingFlow() public {
        // Given : 2 actors and initial staking token amounts
        address user1 = address(0x1);
        address user2 = address(0x2);
        uint128 user1InitBalance = uint128(1_000_000 * (10 ** Constants.stableDecimals));
        uint128 user2InitBalance = uint128(4_000_000 * (10 ** Constants.stableDecimals));

        // Given : Fund both users with amount of underlyingTokens
        address asset = address(mockERC20.stable1);
        address rewardToken = address(mockERC20.token1);
        mintERC20TokenTo(asset, user1, user1InitBalance);
        mintERC20TokenTo(asset, user2, user2InitBalance);

        // Given : Add asset and rewardToken to stakingModule
        stakingModule.setAssetAndRewardToken(asset, mockERC20.token1);

        // Given : Both users stake in the stakingModule
        approveERC20TokenFor(asset, address(stakingModule), user1InitBalance, user1);
        approveERC20TokenFor(asset, address(stakingModule), user2InitBalance, user2);

        vm.prank(user1);
        stakingModule.stake(0, asset, user1InitBalance, user1);
        vm.prank(user2);
        stakingModule.stake(0, asset, user2InitBalance, user2);

        // Given : Mock rewards
        uint128 rewardAmount1 = uint128(1_000_000 * (10 ** Constants.tokenDecimals));
        stakingModule.setActualRewardBalance(asset, rewardAmount1);
        mintERC20TokenTo(rewardToken, address(stakingModule), type(uint256).max);

        // When : User1 claims rewards
        // Then : He should receive 1/5 of the rewardAmount1
        vm.prank(user1);
        stakingModule.claimReward(1);

        assertEq(mockERC20.token1.balanceOf(user1), rewardAmount1 / 5);

        // Given : User 1 stakes additional tokens and stakes
        uint128 user1AddedBalance = uint128(3_000_000 * (10 ** Constants.stableDecimals));
        mintERC20TokenTo(asset, user1, user1AddedBalance);
        approveERC20TokenFor(asset, address(stakingModule), user1AddedBalance, user1);

        vm.prank(user1);
        stakingModule.stake(1, asset, user1AddedBalance, user1);

        // Given : Add 1 mio more rewards
        uint128 rewardAmount2 = uint128(1_000_000 * (10 ** Constants.tokenDecimals));
        stakingModule.setActualRewardBalance(asset, rewardAmount2);

        // Given : A third user stakes while there is no reward increase (this shouldn't accrue rewards for him and not impact other user rewards)
        address user3 = address(0x3);
        mintERC20TokenTo(asset, user3, user1AddedBalance);
        approveERC20TokenFor(asset, address(stakingModule), user1AddedBalance, user3);

        vm.prank(user3);
        stakingModule.stake(0, asset, user1AddedBalance, user3);

        // When : User1 withdraws
        // Then : He should receive half of rewardAmount2
        vm.prank(user1);
        stakingModule.withdraw(1, user1InitBalance + user1AddedBalance);

        assertEq(mockERC20.token1.balanceOf(user1), (rewardAmount1 / 5) + (rewardAmount2 / 2));
        assertEq(mockERC20.stable1.balanceOf(user1), user1InitBalance + user1AddedBalance);

        // When : User2 withdraws
        // Then : He should receive 4/5 of rewards1 + 1/2 of rewards2
        vm.prank(user2);
        stakingModule.withdraw(2, user2InitBalance);

        assertEq(mockERC20.token1.balanceOf(user2), ((4 * rewardAmount1) / 5) + (rewardAmount2 / 2));
        assertEq(mockERC20.stable1.balanceOf(user2), user2InitBalance);

        // When : User2 calls getRewards()
        // Then : He should not have accrued any rewards
        vm.prank(user3);
        stakingModule.claimReward(3);

        assertEq(mockERC20.token1.balanceOf(user3), 0);
    }
}
