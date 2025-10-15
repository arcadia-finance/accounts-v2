/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import {
    StakedAerodromeAM_Fuzz_Test,
    AbstractStakingAM_Fuzz_Test,
    StakingAM,
    ERC20Mock
} from "./_StakedAerodromeAM.fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "mint" of contract "StakedAerodromeAM".
 */
contract Mint_StakedAerodromeAM_Fuzz_Test is StakedAerodromeAM_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedAerodromeAM_Fuzz_Test.setUp();
    }

    function testFuzz_Revert_mint_ZeroAmount(address asset) public {
        // The stake function should revert when trying to stake 0 amount.
        vm.expectRevert(StakingAM.ZeroAmount.selector);
        stakedAerodromeAM.mint(asset, 0);
    }

    function testFuzz_Revert_mint_AssetNotAllowed(uint8 assetDecimals, uint128 amount, address account_) public {
        // Given : Amount is greater than zero
        vm.assume(amount > 0);

        assetDecimals = uint8(bound(assetDecimals, 0, 18));
        address asset = address(new ERC20Mock("Asset", "AST", assetDecimals));

        deal(asset, account_, amount, true);
        vm.prank(account_);
        ERC20Mock(asset).approve(address(stakedAerodromeAM), amount);

        // When : Calling Stake
        // Then : The function should revert as the asset has not been added to the stakedAerodromeAM.
        vm.prank(account_);
        vm.expectRevert(StakingAM.AssetNotAllowed.selector);
        stakedAerodromeAM.mint(asset, amount);
    }

    function testFuzz_Success_mint_TotalStakedForAssetGreaterThan0(
        AbstractStakingAM_Fuzz_Test.StakingAMStateForAsset memory assetState,
        uint128 amount,
        address account_
    ) public canReceiveERC721(account_) {
        vm.assume(account_ != address(0));

        // Given : the aeroPool is allowed in the Registry
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));
        vm.assume(account_ != address(aeroPool));
        vm.assume(account_ != aeroPool.poolFees());

        // Given : Valid aeroGauge
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);
        vm.assume(account_ != address(aeroGauge));
        vm.assume(account_ != address(voter));

        // And : Add asset and aeroGauge to the AM
        stakedAerodromeAM.addAsset(address(aeroGauge));

        {
            // And: Valid state.
            StakingAM.PositionState memory positionState;
            (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

            // And: State is persisted.
            setStakedAerodromeAMState(assetState, positionState, address(aeroPool), 0);

            // And: updated totalStake should not be greater than uint128.
            // And: Amount staked is greater than zero.
            vm.assume(assetState.totalStaked < type(uint128).max);
            amount = uint128(bound(amount, 1, type(uint128).max - assetState.totalStaked));

            deal(address(aeroPool), account_, amount);
            vm.prank(account_);
            ERC20Mock(address(aeroPool)).approve(address(stakedAerodromeAM), amount);
        }

        // When:  A user is staking via the Staking Module.
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.LiquidityIncreased(1, address(aeroPool), amount);
        uint256 positionId = stakedAerodromeAM.mint(address(aeroPool), amount);

        // Then: Assets should have been transferred to the aeroGauge.
        assertEq(aeroGauge.balanceOf(address(stakedAerodromeAM)), amount);

        // And: New position has been minted to Account.
        assertEq(stakedAerodromeAM.ownerOf(positionId), account_);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
                newPositionState.asset,
                newPositionState.amountStaked,
                newPositionState.lastRewardPerTokenPosition,
                newPositionState.lastRewardPosition
            ) = stakedAerodromeAM.positionState(positionId);
        assertEq(newPositionState.asset, address(aeroPool));
        assertEq(newPositionState.amountStaked, amount);
        uint128 currentRewardPerToken;
        unchecked {
            currentRewardPerToken = assetState.lastRewardPerTokenGlobal
                + uint128(assetState.currentRewardGlobal.mulDivDown(1e18, assetState.totalStaked));
        }
        assertEq(newPositionState.lastRewardPerTokenPosition, currentRewardPerToken);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset state should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedAerodromeAM.assetState(address(aeroPool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.totalStaked, assetState.totalStaked + amount);
        assertEq(stakedAerodromeAM.REWARD_TOKEN().balanceOf(address(stakedAerodromeAM)), assetState.currentRewardGlobal);
    }

    function testFuzz_Success_mint_TotalStakedForAssetIsZero(
        StakingAMStateForAsset memory assetState,
        uint128 amount,
        address account_
    ) public canReceiveERC721(account_) {
        vm.assume(account_ != address(0));

        // Given : the aeroPool is allowed in the Registry
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));
        vm.assume(account_ != address(aeroPool));
        vm.assume(account_ != aeroPool.poolFees());

        // Given : Valid aeroGauge
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);
        vm.assume(account_ != address(aeroGauge));
        vm.assume(account_ != address(voter));

        // And : Add asset and aeroGauge to the AM
        stakedAerodromeAM.addAsset(address(aeroGauge));

        // And: Valid state.
        StakingAM.PositionState memory positionState;
        (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

        // And: TotalStaked is 0.
        assetState.totalStaked = 0;

        // And: State is persisted.
        setStakedAerodromeAMState(assetState, positionState, address(aeroPool), 0);

        // And: Amount staked is greater than zero.
        amount = uint128(bound(amount, 1, type(uint128).max));

        // And : Account has a balanceOf aeroPool LP tokens
        deal(address(aeroPool), account_, amount);
        vm.prank(account_);
        ERC20Mock(address(aeroPool)).approve(address(stakedAerodromeAM), amount);

        // When: A user is staking via the Staking Module.
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.LiquidityIncreased(1, address(aeroPool), amount);
        uint256 positionId = stakedAerodromeAM.mint(address(aeroPool), amount);

        // Then: Assets should have been transferred to the aeroGauge.
        assertEq(aeroGauge.balanceOf(address(stakedAerodromeAM)), amount);

        // And: New position has been minted to Account.
        assertEq(stakedAerodromeAM.ownerOf(positionId), account_);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
                newPositionState.asset,
                newPositionState.amountStaked,
                newPositionState.lastRewardPerTokenPosition,
                newPositionState.lastRewardPosition
            ) = stakedAerodromeAM.positionState(positionId);
        assertEq(newPositionState.asset, address(aeroPool));
        assertEq(newPositionState.amountStaked, amount);
        assertEq(newPositionState.lastRewardPerTokenPosition, assetState.lastRewardPerTokenGlobal);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset state should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedAerodromeAM.assetState(address(aeroPool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, amount);
    }
}
