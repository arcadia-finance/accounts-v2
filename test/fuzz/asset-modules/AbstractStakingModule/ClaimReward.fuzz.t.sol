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

    function testFuzz_Revert_claimReward_NotOwner(address owner, address randomAddress, uint256 positionId) public {
        // Given : Owner of positionId is not randomAddress
        stakingModule.setOwnerOfPositionId(owner, positionId);

        // When : randomAddress calls claimReward for positionId
        // Then : It should revert as randomAddress is not owner of the positionId
        vm.startPrank(randomAddress);
        vm.expectRevert(StakingModule.NotOwner.selector);
        stakingModule.claimReward(positionId);
        vm.stopPrank();
    }

    function testFuzz_Success_claimReward_ZeroReward(
        address asset,
        address account,
        uint128 lastRewardGlobal,
        uint128 lastRewardPerTokenGlobal,
        uint128 positionAmount,
        uint256 positionId
    ) public {
        // Given : lastRewardGlobal > 0, since we are claiming the rewards of the external staking contract via claimReward() we have to validate that lastRewardGlobal is set to 0 after. currentRewardGlobal should be equal to lastRewardGlobal, as account should not earn over that period.
        vm.assume(lastRewardGlobal > 0);
        stakingModule.setLastRewardGlobal(asset, lastRewardGlobal);
        stakingModule.setActualRewardBalance(asset, lastRewardGlobal);

        // Given : lastRewardPerTokenGlobal should be equal to lastRewardPerTokenPosition (= no reward currentRewardPosition for position).
        stakingModule.setLastRewardPerTokenGlobal(asset, lastRewardPerTokenGlobal);
        stakingModule.setLastRewardPerTokenPosition(positionId, lastRewardPerTokenGlobal);

        // Given : Correct asset is given in position
        stakingModule.setAssetInPosition(asset, positionId);

        // Given : Position has a non-zero amount staked.
        vm.assume(positionAmount > 0);
        stakingModule.setAmountStakedForPosition(positionId, positionAmount);
        stakingModule.setTotalStaked(asset, positionAmount);

        // Given : Account is owner of the position.
        stakingModule.setOwnerOfPositionId(account, positionId);

        // When : Account calls claimReward().
        vm.prank(account);
        stakingModule.claimReward(positionId);

        // Then : lastRewardGlobal and rewards of Account should be 0.
        (, uint128 lastRewardGlobal_,) = stakingModule.assetState(asset);
        assertEq(lastRewardGlobal_, 0);
        (,,, uint128 lastRewardPosition_) = stakingModule.positionState(positionId);
        assertEq(lastRewardPosition_, 0);
    }

    function testFuzz_Success_claimReward_RewardGreaterThanZero(
        address account,
        uint256 positionId,
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint128 rewardIncrease,
        uint8 assetDecimals,
        uint8 rewardTokenDecimals
    ) public {
        // Given : account != zero address
        vm.assume(account != address(0));

        // Given : owner of ERC721 positionId is Account
        stakingModule.setOwnerOfPositionId(account, positionId);

        // Given : Add an asset and reward token pair
        (address[] memory assets,) = addAssets(1, assetDecimals, rewardTokenDecimals);
        address asset = assets[0];

        // Given : Valid state
        (assetState, positionState) = setStakingModuleState(assetState, positionState, asset, positionId);

        // Given : Account has a positive balance
        vm.assume(positionState.amountStaked > 0);

        // Given : Actual rewards from external staking contract are > previous claimable rewards. Thus rewardIncrease > 0.
        vm.assume(assetState.lastRewardGlobal < type(uint128).max);
        rewardIncrease = uint128(bound(rewardIncrease, 1, type(uint128).max - assetState.lastRewardGlobal));
        stakingModule.setActualRewardBalance(asset, assetState.lastRewardGlobal + rewardIncrease);

        // Given : The claim function on the external staking contract is not implemented, thus we fund the stakingModule with reward tokens that should be transferred.
        uint256 currentRewardPosition = stakingModule.rewardOf(positionId);
        mintERC20TokenTo(
            address(stakingModule.assetToRewardToken(asset)), address(stakingModule), currentRewardPosition
        );

        // Given : currentRewardPosition > 0, for very small reward increase and high balances, it could return zero.
        vm.assume(currentRewardPosition > 0);

        // Calculate currentRewardPerToken before calling claimReward(), used for final check.
        uint256 currentRewardPerToken =
            assetState.lastRewardPerTokenGlobal + uint256(rewardIncrease).mulDivDown(1e18, assetState.totalStaked);
        // As our givenValidState is not valid anymore since we update actualRewardBalance above, we should assume currentRewardPerToken is smalller than max uint128 value.
        vm.assume(currentRewardPerToken <= type(uint128).max);

        // When : Account calls claimReward()
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.RewardPaid(
            account, address(stakingModule.assetToRewardToken(asset)), uint128(currentRewardPosition)
        );
        stakingModule.claimReward(positionId);
        vm.stopPrank();

        // Then : Account should have received the reward tokens.
        assertEq(currentRewardPosition, stakingModule.assetToRewardToken(asset).balanceOf(account));

        // And : positionState should be updated.
        (,, uint128 lastRewardPerTokenPosition, uint128 lastRewardPosition) = stakingModule.positionState(positionId);
        assertEq(lastRewardPosition, 0);
        // lastRewardPerTokenPosition should be equal to the value of currentRewardPerToken at the time of calling claimReward().
        assertEq(lastRewardPerTokenPosition, currentRewardPerToken);

        // And : assetState should be updated.
        (uint128 lastRewardPerTokenGlobal, uint128 lastRewardGlobal,) = stakingModule.assetState(asset);
        assertEq(lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(lastRewardGlobal, 0);
    }
}
