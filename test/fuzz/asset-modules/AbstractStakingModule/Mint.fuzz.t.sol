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

    function testFuzz_Revert_mint_AssetNotAllowed(uint8 assetDecimals, uint128 amount, address account) public {
        // Given : Amount is greater than zero
        vm.assume(amount > 0);

        assetDecimals = uint8(bound(assetDecimals, 0, 18));
        address asset = address(new ERC20Mock("Asset", "AST", assetDecimals));

        address[] memory tokens = new address[](1);
        tokens[0] = asset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        mintERC20TokensTo(tokens, account, amounts);
        approveERC20TokensFor(tokens, address(stakingModule), amounts, account);

        // When : Calling Stake
        // Then : The function should revert as the asset has not been added to the Staking Module.
        vm.prank(account);
        vm.expectRevert(StakingModule.AssetNotAllowed.selector);
        stakingModule.mint(asset, amount);
    }

    function testFuzz_Success_mint_TotalStakedForAssetGreaterThan0(
        uint8 assetDecimals,
        StakingModuleStateForAsset memory assetState,
        uint128 amount,
        address account
    ) public notTestContracts(account) {
        vm.assume(account != address(0));
        vm.assume(account != address(stakingModule));
        vm.assume(account != address(rewardToken));

        address asset;
        {
            // Given: An Asset i added to the stakingModule.
            asset = addAsset(assetDecimals);
            vm.assume(account != asset);

            // And: Valid state.
            StakingModule.PositionState memory positionState;
            (assetState, positionState) = givenValidStakingModuleState(assetState, positionState);

            // And: State is persisted.
            setStakingModuleState(assetState, positionState, asset, 0);

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

        // When:  A user is staking via the Staking Module.
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.LiquidityIncreased(1, asset, amount);
        uint256 positionId = stakingModule.mint(asset, amount);

        // Then: Assets should have been transferred to the Staking Module.
        assertEq(ERC20Mock(asset).balanceOf(address(stakingModule)), amount);

        // And: New position has been minted to Account.
        assertEq(stakingModule.ownerOf(positionId), account);

        // And: Position state should be updated correctly.
        StakingModule.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakingModule.positionState(positionId);
        assertEq(newPositionState.asset, asset);
        assertEq(newPositionState.amountStaked, amount);
        uint256 deltaReward = assetState.currentRewardGlobal - assetState.lastRewardGlobal;
        uint128 currentRewardPerToken;
        unchecked {
            currentRewardPerToken =
                assetState.lastRewardPerTokenGlobal + uint128(deltaReward.mulDivDown(1e18, assetState.totalStaked));
        }
        assertEq(newPositionState.lastRewardPerTokenPosition, currentRewardPerToken);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset state should be updated correctly.
        StakingModule.AssetState memory newAssetState;
        (, newAssetState.lastRewardPerTokenGlobal, newAssetState.lastRewardGlobal, newAssetState.totalStaked) =
            stakingModule.assetState(asset);
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.lastRewardGlobal, assetState.currentRewardGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked + amount);
    }

    function testFuzz_Success_mint_TotalStakedForAssetIsZero(
        uint8 assetDecimals,
        StakingModuleStateForAsset memory assetState,
        uint128 amount,
        address account
    ) public notTestContracts(account) {
        vm.assume(account != address(0));
        vm.assume(account != address(stakingModule));
        vm.assume(account != address(rewardToken));

        // Given: An Asset is added to the stakingModule.
        address asset = addAsset(assetDecimals);
        vm.assume(account != asset);

        // And: Valid state.
        StakingModule.PositionState memory positionState;
        (assetState, positionState) = givenValidStakingModuleState(assetState, positionState);

        // And: TotalStaked is 0.
        assetState.totalStaked = 0;

        // And: State is persisted.
        setStakingModuleState(assetState, positionState, asset, 0);

        // And: Amount staked is greater than zero.
        amount = uint128(bound(amount, 1, type(uint128).max));

        address[] memory tokens = new address[](1);
        tokens[0] = asset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        mintERC20TokensTo(tokens, account, amounts);
        approveERC20TokensFor(tokens, address(stakingModule), amounts, account);

        // When:  A user is staking via the Staking Module.
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.LiquidityIncreased(1, asset, amount);
        uint256 positionId = stakingModule.mint(asset, amount);

        // Then: Assets should have been transferred to the Staking Module.
        assertEq(ERC20Mock(asset).balanceOf(address(stakingModule)), amount);

        // And: New position has been minted to Account.
        assertEq(stakingModule.ownerOf(positionId), account);

        // And: Position state should be updated correctly.
        StakingModule.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakingModule.positionState(positionId);
        assertEq(newPositionState.asset, asset);
        assertEq(newPositionState.amountStaked, amount);
        assertEq(newPositionState.lastRewardPerTokenPosition, assetState.lastRewardPerTokenGlobal);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset state should be updated correctly.
        StakingModule.AssetState memory newAssetState;
        (, newAssetState.lastRewardPerTokenGlobal, newAssetState.lastRewardGlobal, newAssetState.totalStaked) =
            stakingModule.assetState(asset);
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.lastRewardGlobal, assetState.lastRewardGlobal);
        assertEq(newAssetState.totalStaked, amount);
    }
}
