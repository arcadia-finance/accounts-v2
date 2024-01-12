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
contract ClaimReward_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
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

    // Note : add revert scenario for non owner
    function testFuzz_Success_claimReward_ZeroReward(
        address asset,
        address account,
        uint128 lastRewardGlobal,
        uint128 lastRewardPerTokenGlobal,
        uint128 positionAmount,
        uint256 tokenId
    ) public {
        // Given : lastRewardGlobal > 0, since we are claiming the rewards of the external staking contract via claimReward() we have to validate that lastRewardGlobal is set to 0 after. currentRewardGlobal should be equal to lastRewardGlobal, as account should not earn over that period.
        vm.assume(lastRewardGlobal > 0);
        stakingModule.setLastRewardGlobal(asset, lastRewardGlobal);
        stakingModule.setActualRewardBalance(asset, lastRewardGlobal);

        // Given : lastRewardPerTokenGlobal should be equal to lastRewardPerTokenPosition (= no reward currentRewardPosition for position).
        stakingModule.setLastRewardPerTokenGlobal(asset, lastRewardPerTokenGlobal);
        stakingModule.setLastRewardPerTokenPosition(tokenId, lastRewardPerTokenGlobal);

        // Given : Correct asset is given in position
        stakingModule.setAssetInPosition(asset, tokenId);

        // Given : Position has a non-zero amount staked.
        vm.assume(positionAmount > 0);
        stakingModule.setAmountStakedForPosition(tokenId, positionAmount);
        stakingModule.setTotalStaked(asset, positionAmount);

        // Given : Account is owner of the position.
        stakingModule.setOwnerOfTokenId(account, tokenId);

        // When : Account calls claimReward().
        vm.prank(account);
        stakingModule.claimReward(tokenId);

        // Then : lastRewardGlobal and rewards of Account should be 0.
        (, uint128 lastRewardGlobal_,) = stakingModule.assetState(asset);
        assertEq(lastRewardGlobal_, 0);
        (,,, uint128 lastRewardPosition_) = stakingModule.positionState(tokenId);
        assertEq(lastRewardPosition_, 0);
    }

    function testFuzz_Success_claimReward_RewardGreaterThanZero(
        address account,
        uint256 tokenId,
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint128 rewardIncrease,
        uint8 assetDecimals,
        uint8 rewardTokenDecimals
    ) public {
        // Given : account != zero address
        vm.assume(account != address(0));

        // Given : owner of ERC721 tokenId is Account
        stakingModule.setOwnerOfTokenId(account, tokenId);

        // Given : Add an asset and reward token pair
        (address[] memory assets,) = addAssets(1, assetDecimals, rewardTokenDecimals);
        address asset = assets[0];

        // Given : Valid state
        (assetState, positionState) = setStakingModuleState(assetState, positionState, asset, tokenId);

        // Given : Account has a positive balance
        vm.assume(positionState.amountStaked > 0);

        // Given : Actual rewards from external staking contract are > previous claimable rewards. Thus rewardIncrease > 0.
        vm.assume(assetState.lastRewardGlobal < type(uint128).max);
        rewardIncrease = uint128(bound(rewardIncrease, 1, type(uint128).max - assetState.lastRewardGlobal));
        stakingModule.setActualRewardBalance(asset, assetState.lastRewardGlobal + rewardIncrease);

        // Given : The claim function on the external staking contract is not implemented, thus we fund the stakingModule with reward tokens that should be transferred.
        uint256 currentRewardPosition = stakingModule.rewardOf(tokenId);
        mintERC20TokenTo(
            address(stakingModule.assetToRewardToken(asset)), address(stakingModule), currentRewardPosition
        );

        // Given : currentRewardPosition > 0, for very small reward increase and high balances, it could return zero.
        vm.assume(currentRewardPosition > 0);

        // When : Account calls claimReward()
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.RewardPaid(
            account, address(stakingModule.assetToRewardToken(asset)), uint128(currentRewardPosition)
        );
        stakingModule.claimReward(tokenId);
        vm.stopPrank();

        // Then : Account should have received the reward tokens.
        assertEq(currentRewardPosition, stakingModule.assetToRewardToken(asset).balanceOf(account));
        (,,, currentRewardPosition) = stakingModule.positionState(tokenId);
        assertEq(currentRewardPosition, 0);
    }
}
