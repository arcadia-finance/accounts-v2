/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, StakingModule, ERC20Mock } from "./_AbstractStakingModule.fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "mint" of contract "StakingModule".
 */
contract Mint_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
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

    function testFuzz_Revert_mint_ZeroAmount(address asset) public {
        // The stake function should revert when trying to stake 0 amount.
        vm.expectRevert(StakingModule.ZeroAmount.selector);
        stakingModule.mint(asset, 0);
    }

    function testFuzz_Revert_mint_AssetNotAllowed(address asset, uint128 amount) public {
        // Given : Amount is greater than zero
        vm.assume(amount > 0);
        // When : Calling Stake
        // Then : The function should revert as the asset has not been added to the Staking Module.
        vm.expectRevert(StakingModule.AssetNotAllowed.selector);
        stakingModule.mint(asset, amount);
    }

    function testFuzz_Success_mint_TotalStakedForAssetGreaterThan0(
        uint8 assetDecimals,
        uint8 rewardTokenDecimals,
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint256 positionId,
        uint128 amount,
        address account
    ) public notTestContracts(account) {
        // Given : Can't stake zero amount
        vm.assume(amount > 0);
        // Given : positionId is not equal to 1, as by staking we will mint id 1.
        vm.assume(positionId != 1);

        // Given : An Asset and reward token pair are added to the stakingModule
        (address[] memory assets,) = addAssets(1, assetDecimals, rewardTokenDecimals);
        vm.assume(account != assets[0]);
        address asset = assets[0];

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        mintERC20TokensTo(assets, account, amounts);
        approveERC20TokensFor(assets, address(stakingModule), amounts, account);

        // Given : Valid state
        (assetState, positionState) = setStakingModuleState(assetState, positionState, asset, positionId);

        // Given : TotalStaked is greater than 0 and updated totalStake should not be greater than uint128.
        (,, uint128 totalStaked) = stakingModule.assetState(asset);
        vm.assume(totalStaked > 0);
        vm.assume(totalStaked < type(uint128).max - amount);

        // When :  A user is staking via the Staking Module
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.Minted(account, 1, asset, amount);
        uint256 newPositionId = stakingModule.mint(asset, amount);

        // Cache value to avoid stack too deep
        StakingModuleStateForAsset memory assetStateStack = assetState;
        uint256 amountStack = amount;

        // Then : Assets should have been transferred to the Staking Module
        assertEq(ERC20Mock(asset).balanceOf(address(stakingModule)), amountStack);

        // And : New position has been minted to Account
        assertEq(stakingModule.ownerOf(newPositionId), account);

        // And : Asset and position values should be updated correctly
        StakingModule.PositionState memory newPositionState;
        StakingModule.AssetState memory newAssetState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakingModule.positionState(1);

        (newAssetState.lastRewardPerTokenGlobal, newAssetState.lastRewardGlobal, newAssetState.totalStaked) =
            stakingModule.assetState(asset);

        assertEq(newPositionState.asset, asset);
        assertEq(newPositionState.amountStaked, amountStack);
        uint256 deltaReward = assetStateStack.currentRewardGlobal - assetStateStack.lastRewardGlobal;
        uint256 currentRewardPerToken =
            assetStateStack.lastRewardPerTokenGlobal + deltaReward.mulDivDown(1e18, assetStateStack.totalStaked);
        assertEq(newPositionState.lastRewardPerTokenPosition, currentRewardPerToken);
        assertEq(newPositionState.lastRewardPosition, 0);

        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.lastRewardGlobal, assetStateStack.currentRewardGlobal);
        assertEq(newAssetState.totalStaked, assetStateStack.totalStaked + amountStack);
    }

    function testFuzz_Success_mint_TotalStakedForAssetIsZero(
        uint8 assetDecimals,
        uint8 rewardTokenDecimals,
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint256 positionId,
        uint128 amount,
        address account
    ) public notTestContracts(account) {
        // Given : Can't stake zero amount
        vm.assume(amount > 0);
        // Given : positionId is not equal to 1, as by staking we will mint id 1.
        vm.assume(positionId != 1);

        // Given : A staking token and reward token pair are added to the stakingModule
        (address[] memory assets,) = addAssets(1, assetDecimals, rewardTokenDecimals);
        vm.assume(account != assets[0]);
        address asset = assets[0];

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        mintERC20TokensTo(assets, account, amounts);
        approveERC20TokensFor(assets, address(stakingModule), amounts, account);

        // Given : Valid state
        (assetState, positionState) = setStakingModuleState(assetState, positionState, asset, positionId);

        // Given : TotalStaked is 0
        stakingModule.setTotalStaked(asset, 0);

        // When :  A user is staking via the Staking Module
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.Minted(account, 1, asset, amount);
        uint256 newPositionId = stakingModule.mint(asset, amount);

        // Cache value to avoid stack too deep
        uint256 amountStack = amount;

        // Then : Assets should have been transferred to the Staking Module
        assertEq(ERC20Mock(asset).balanceOf(address(stakingModule)), amountStack);

        // And : New position has been minted to Account
        assertEq(stakingModule.ownerOf(newPositionId), account);

        // And : Asset and position values should be updated correctly
        StakingModule.PositionState memory newPositionState;
        StakingModule.AssetState memory newAssetState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakingModule.positionState(1);

        (newAssetState.lastRewardPerTokenGlobal, newAssetState.lastRewardGlobal, newAssetState.totalStaked) =
            stakingModule.assetState(asset);

        assertEq(newPositionState.asset, asset);
        assertEq(newPositionState.amountStaked, amountStack);
        assertEq(newPositionState.lastRewardPerTokenPosition, 0);
        assertEq(newPositionState.lastRewardPosition, 0);

        assertEq(newAssetState.lastRewardPerTokenGlobal, 0);
        assertEq(newAssetState.lastRewardGlobal, 0);
        assertEq(newAssetState.totalStaked, amountStack);
    }
}
