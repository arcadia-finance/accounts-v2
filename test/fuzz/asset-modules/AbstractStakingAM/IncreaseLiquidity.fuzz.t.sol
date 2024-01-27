/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingAM_Fuzz_Test, StakingAM, ERC20Mock } from "./_AbstractStakingAM.fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "increaseLiquidity" of contract "StakingAM".
 */
contract IncreaseLiquidity_AbstractStakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                             TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_increaseLiquidity_ZeroAmount(uint96 positionId) public {
        // The stake function should revert when trying to stake 0 amount.
        vm.expectRevert(StakingAM.ZeroAmount.selector);
        stakingAM.increaseLiquidity(positionId, 0);
    }

    function testFuzz_Revert_increaseLiquidity_NotOwner(
        address account,
        address randomAddress,
        uint128 amount,
        uint96 positionId,
        uint8 assetDecimals
    ) public notTestContracts(account) {
        // Given : Amount is greater than zero
        vm.assume(amount > 0);
        // Given : positionId is greater than 0
        vm.assume(positionId > 0);
        // Given : Owner of positionId is not the Account
        stakingAM.setOwnerOfPositionId(randomAddress, positionId);
        // Given : A staking token is added to the stakingAM
        address asset = addAsset(assetDecimals);

        address[] memory tokens = new address[](1);
        tokens[0] = asset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        mintERC20TokensTo(tokens, account, amounts);
        approveERC20TokensFor(tokens, address(stakingAM), amounts, account);

        // When : Calling Stake
        // Then : The function should revert as the Account is not the owner of the positionId.
        vm.startPrank(account);
        vm.expectRevert(StakingAM.NotOwner.selector);
        stakingAM.increaseLiquidity(positionId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_increaseLiquidity(
        uint8 assetDecimals,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        uint96 positionId,
        uint128 amount,
        address account
    ) public notTestContracts(account) {
        address asset;
        {
            // Given : A staking token is added to the stakingAM
            asset = addAsset(assetDecimals);

            // Given : Valid state
            (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

            // And: State is persisted.
            setStakingAMState(assetState, positionState, asset, positionId);

            // Given : Owner of positionId is Account
            stakingAM.setOwnerOfPositionId(account, positionId);

            // And: updated totalStake should not be greater than uint128.
            // And: Amount staked is greater than zero.
            vm.assume(assetState.totalStaked < type(uint128).max);
            amount = uint128(bound(amount, 1, type(uint128).max - assetState.totalStaked));

            address[] memory tokens = new address[](1);
            tokens[0] = asset;

            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amount;

            mintERC20TokensTo(tokens, account, amounts);
            approveERC20TokensFor(tokens, address(stakingAM), amounts, account);
        }

        // When :  A user is increasing liquidity via the Staking Module
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingAM.LiquidityIncreased(positionId, asset, amount);
        stakingAM.increaseLiquidity(positionId, amount);

        // Then : Assets should have been transferred to the Staking Module
        assertEq(ERC20Mock(asset).balanceOf(address(stakingAM)), amount);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakingAM.positionState(positionId);
        assertEq(newPositionState.asset, asset);
        assertEq(newPositionState.amountStaked, positionState.amountStaked + amount);
        uint256 deltaReward = assetState.currentRewardGlobal - assetState.lastRewardGlobal;
        uint128 currentRewardPerToken;
        unchecked {
            currentRewardPerToken =
                assetState.lastRewardPerTokenGlobal + uint128(deltaReward.mulDivDown(1e18, assetState.totalStaked));
        }
        assertEq(newPositionState.lastRewardPerTokenPosition, currentRewardPerToken);
        uint128 deltaRewardPerToken;
        unchecked {
            deltaRewardPerToken = currentRewardPerToken - positionState.lastRewardPerTokenPosition;
        }
        deltaReward = uint256(positionState.amountStaked).mulDivDown(deltaRewardPerToken, 1e18);
        assertEq(newPositionState.lastRewardPosition, positionState.lastRewardPosition + deltaReward);

        // And : Asset values should be updated correctly
        StakingAM.AssetState memory newAssetState;
        (, newAssetState.lastRewardPerTokenGlobal, newAssetState.lastRewardGlobal, newAssetState.totalStaked) =
            stakingAM.assetState(asset);
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.lastRewardGlobal, assetState.currentRewardGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked + amount);
    }
}
