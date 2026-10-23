/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AbstractStakingAM_Fuzz_Test, StakingAM, ERC20Mock } from "./_AbstractStakingAM.fuzz.t.sol";
import { stdError } from "../../../../lib/forge-std/src/StdError.sol";

/**
 * @notice Fuzz tests for the function "mint" of contract "StakingAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract Mint_AbstractStakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_mint_ZeroAmount(address asset) public {
        // The stake function should revert when trying to stake 0 amount.
        vm.expectRevert(StakingAM.ZeroAmount.selector);
        stakingAM.mint(asset, 0);
    }

    function testFuzz_Revert_mint_AssetNotAllowed(uint8 assetDecimals, uint128 amount, address account_) public {
        // Given : Amount is greater than zero
        amount = uint128(bound(amount, 1, type(uint128).max));

        assetDecimals = uint8(bound(assetDecimals, 0, 18));
        address asset = address(new ERC20Mock("Asset", "AST", assetDecimals));

        address[] memory tokens = new address[](1);
        tokens[0] = asset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        deal(asset, account_, amount, true);
        vm.prank(account_);
        ERC20Mock(asset).approve(address(stakingAM), amount);

        // When : Calling Stake
        // Then : The function should revert as the asset has not been added to the Staking Module.
        vm.prank(account_);
        vm.expectRevert(StakingAM.AssetNotAllowed.selector);
        stakingAM.mint(asset, amount);
    }

    function testFuzz_Revert_mint_TotalStakedOverflow(
        uint8 assetDecimals,
        uint128 totalStaked,
        uint128 amount,
        address account_
    ) public {
        vm.assume(account_ != address(0));
        vm.assume(account_ != address(stakingAM));

        // Given : An Asset is added to the stakingAM.
        address asset = addAsset(assetDecimals);
        vm.assume(account_ != asset);

        // And : The amount staked does not fit the uint128 total staked of the Asset.
        totalStaked = uint128(bound(totalStaked, 1, type(uint128).max));
        amount = uint128(bound(amount, type(uint128).max - totalStaked + 1, type(uint128).max));
        stakingAM.setTotalStaked(asset, totalStaked);

        deal(asset, account_, amount, true);
        vm.startPrank(account_);
        ERC20Mock(asset).approve(address(stakingAM), amount);

        // When : A user mints a position.
        // Then : It reverts on the checked addition of the total staked.
        vm.expectRevert(stdError.arithmeticError);
        stakingAM.mint(asset, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_mint_TotalStakedForAssetGreaterThan0(
        uint8 assetDecimals,
        StakingAMStateForAsset memory assetState,
        StakingAMStateForSurplus memory surplusState,
        uint128 amount,
        address account_
    ) public canReceiveERC721(account_) {
        vm.assume(account_ != address(0));
        vm.assume(account_ != address(stakingAM));
        vm.assume(account_ != address(rewardToken));

        address asset;
        {
            // Given: An Asset is added to the stakingAM.
            asset = addAsset(assetDecimals);
            vm.assume(account_ != asset);

            // And: Valid state.
            StakingAM.PositionState memory positionState;
            (assetState, positionState) =
                givenValidStakingAMState(assetState, positionState, surplusState, 0, type(uint128).max - 1);

            // And: State is persisted.
            setStakingAMState(assetState, positionState, surplusState, asset, 0);

            // And: updated totalStake should not be greater than uint128.
            // And: Amount staked is greater than zero.
            amount = uint128(bound(amount, 1, type(uint128).max - assetState.totalStaked));

            deal(asset, account_, amount, true);
            vm.prank(account_);
            ERC20Mock(asset).approve(address(stakingAM), amount);
        }

        // When:  A user is staking via the Staking Module.
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.LiquidityIncreased(1, asset, amount);
        uint256 positionId = stakingAM.mint(asset, amount);

        // Then: Assets should have been transferred to the Staking Module.
        assertEq(ERC20Mock(asset).balanceOf(address(stakingAM)), amount);

        // And: New position has been minted to Account.
        assertEq(stakingAM.ownerOf(positionId), account_);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakingAM.positionState(positionId);
        assertEq(newPositionState.asset, asset);
        assertEq(newPositionState.amountStaked, amount);
        uint128 currentRewardPerToken = currentRewardPerTokenGlobal(assetState);
        assertEq(newPositionState.lastRewardPerTokenPosition, currentRewardPerToken);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset state should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) = stakingAM.assetState(asset);
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.totalStaked, assetState.totalStaked + amount);

        // And: The reward token balance is cached.
        assertEq(stakingAM.getLastRewardBalance(), rewardToken.balanceOf(address(stakingAM)));
    }

    function testFuzz_Success_mint_TotalStakedForAssetIsZero(
        uint8 assetDecimals,
        StakingAMStateForAsset memory assetState,
        StakingAMStateForSurplus memory surplusState,
        uint128 amount,
        address account_
    ) public canReceiveERC721(account_) {
        vm.assume(account_ != address(0));
        vm.assume(account_ != address(stakingAM));
        vm.assume(account_ != address(rewardToken));

        // Given: An Asset is added to the stakingAM.
        address asset = addAsset(assetDecimals);
        vm.assume(account_ != asset);

        // And: Valid state.
        StakingAM.PositionState memory positionState;
        (assetState, positionState) =
            givenValidStakingAMState(assetState, positionState, surplusState, 0, type(uint128).max - 1);

        // And: TotalStaked is 0.
        assetState.totalStaked = 0;

        // And: State is persisted.
        setStakingAMState(assetState, positionState, surplusState, asset, 0);

        // And: Amount staked is greater than zero.
        amount = uint128(bound(amount, 1, type(uint128).max));

        deal(asset, account_, amount, true);
        vm.prank(account_);
        ERC20Mock(asset).approve(address(stakingAM), amount);

        // When:  A user is staking via the Staking Module.
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.LiquidityIncreased(1, asset, amount);
        uint256 positionId = stakingAM.mint(asset, amount);

        // Then: Assets should have been transferred to the Staking Module.
        assertEq(ERC20Mock(asset).balanceOf(address(stakingAM)), amount);

        // And: New position has been minted to Account.
        assertEq(stakingAM.ownerOf(positionId), account_);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakingAM.positionState(positionId);
        assertEq(newPositionState.asset, asset);
        assertEq(newPositionState.amountStaked, amount);
        assertEq(newPositionState.lastRewardPerTokenPosition, assetState.lastRewardPerTokenGlobal);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset state should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) = stakingAM.assetState(asset);
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, amount);

        // And: The reward token balance is cached.
        assertEq(stakingAM.getLastRewardBalance(), rewardToken.balanceOf(address(stakingAM)));
    }

    function testFuzz_Success_mint_BookedSurplusNotCredited(
        uint8 assetDecimals,
        StakingAMStateForSurplus memory surplusState,
        uint128 amount,
        uint128 amountSecond,
        uint128 reward,
        uint128 booked
    ) public {
        // Given: An Asset is added to the stakingAM.
        address asset = addAsset(assetDecimals);

        // And: Valid surplus state.
        givenValidStakingAMState(surplusState);
        setStakingAMState(surplusState);

        // And: A position is staked, whose stake keeps the reward accumulator in range.
        amount = uint128(bound(amount, 1e18, type(uint128).max / 2));
        uint256 positionId = _stakeSolePosition(asset, amount);

        // And: The staking contract will deliver a reward, of which the hook books a part for the recipient.
        reward = uint128(bound(reward, 1, type(uint128).max));
        booked = uint128(bound(booked, 1, reward));
        stakingAM.setActualRewardBalance(asset, reward);
        stakingAM.setBookedAmount(booked);
        uint256 expectedReward = _credited(amount, reward - booked);

        // And: A second staker holds the Asset, keeping the total in a uint128.
        amountSecond = uint128(bound(amountSecond, 1, type(uint128).max - amount));
        deal(asset, users.accountOwner, amountSecond, true);
        vm.startPrank(users.accountOwner);
        ERC20Mock(asset).approve(address(stakingAM), amountSecond);

        // When: The second staker mints.
        stakingAM.mint(asset, amountSecond);
        vm.stopPrank();

        // Then: The first position accrued the delivered reward less the booked part.
        assertEq(stakingAM.rewardOf(positionId), expectedReward);

        // And: The booked amount is not credited to the position.
        assertEq(stakingAM.bookedSurplus(), surplusState.bookedSurplus + booked);
        assertEq(stakingAM.getLastRewardBalance(), rewardToken.balanceOf(address(stakingAM)));
    }
}
