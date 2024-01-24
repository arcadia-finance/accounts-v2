/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, StakingModule, ERC20Mock } from "./_AbstractStakingModule.fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "increaseLiquidity" of contract "StakingModule".
 */
contract IncreaseLiquidity_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
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

    function testFuzz_Revert_increaseLiquidity_ZeroAmount(uint256 positionId) public {
        // The stake function should revert when trying to stake 0 amount.
        vm.expectRevert(StakingModule.ZeroAmount.selector);
        stakingModule.increaseLiquidity(positionId, 0);
    }

    function testFuzz_Revert_increaseLiquidity_NotOwner(
        address account,
        address randomAddress,
        uint128 amount,
        uint256 positionId,
        uint8 assetDecimals,
        uint8 rewardTokenDecimals
    ) public notTestContracts(account) {
        // Given : Amount is greater than zero
        vm.assume(amount > 0);
        // Given : positionId is greater than 0
        vm.assume(positionId > 0);
        // Given : Owner of positionId is not the Account
        stakingModule.setOwnerOfPositionId(randomAddress, positionId);
        // Given : A staking token and reward token pair are added to the stakingModule
        (address asset,) = addAssets(assetDecimals, rewardTokenDecimals);

        address[] memory tokens = new address[](1);
        tokens[0] = asset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        mintERC20TokensTo(tokens, account, amounts);
        approveERC20TokensFor(tokens, address(stakingModule), amounts, account);

        // When : Calling Stake
        // Then : The function should revert as the Account is not the owner of the positionId.
        vm.startPrank(account);
        vm.expectRevert(StakingModule.NotOwner.selector);
        stakingModule.increaseLiquidity(positionId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_increaseLiquidity(
        uint8 assetDecimals,
        uint8 rewardTokenDecimals,
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint256 positionId,
        uint128 amount,
        address account
    ) public notTestContracts(account) {
        // Given : positionId is not 0
        positionId = bound(positionId, 0, type(uint256).max);

        address asset;
        {
            // Given : A staking token and reward token pair are added to the stakingModule
            (asset,) = addAssets(assetDecimals, rewardTokenDecimals);

            // Given : Valid state
            (assetState, positionState) = givenValidStakingModuleState(assetState, positionState);

            // And: State is persisted.
            setStakingModuleState(assetState, positionState, asset, positionId);

            // Given : Owner of positionId is Account
            stakingModule.setOwnerOfPositionId(account, positionId);

            // And: updated totalStake should not be greater than uint128.
            // And: Amount staked is greater than zero.
            vm.assume(assetState.totalStaked < type(uint128).max);
            amount = uint128(bound(amount, 1, type(uint128).max - assetState.totalStaked));

            address[] memory tokens = new address[](1);
            tokens[0] = asset;

            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amount;

            mintERC20TokensTo(tokens, account, amounts);
            approveERC20TokensFor(tokens, address(stakingModule), amounts, account);
        }

        // When :  A user is increasing liquidity via the Staking Module
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.LiquidityIncreased(positionId, asset, amount);
        stakingModule.increaseLiquidity(positionId, amount);

        // Then : Assets should have been transferred to the Staking Module
        assertEq(ERC20Mock(asset).balanceOf(address(stakingModule)), amount);

        // And: Position state should be updated correctly.
        StakingModule.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakingModule.positionState(positionId);
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
        StakingModule.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.lastRewardGlobal, newAssetState.totalStaked) =
            stakingModule.assetState(asset);
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.lastRewardGlobal, assetState.currentRewardGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked + amount);
    }
}
