/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import {
    StakedAerodromeAM_Fuzz_Test,
    AbstractStakingAM_Fuzz_Test,
    StakingAM,
    ERC20Mock
} from "./_StakedAerodromeAM.fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

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
        approveERC20TokensFor(tokens, address(stakedAerodromeAM), amounts, account);

        // When : Calling Stake
        // Then : The function should revert as the asset has not been added to the stakedAerodromeAM.
        vm.prank(account);
        vm.expectRevert(StakingAM.AssetNotAllowed.selector);
        stakedAerodromeAM.mint(asset, amount);
    }

    function testFuzz_Success_mint_TotalStakedForAssetGreaterThan0(
        AbstractStakingAM_Fuzz_Test.StakingAMStateForAsset memory assetState,
        uint128 amount,
        address account
    ) public canReceiveERC721(account) {
        vm.assume(account != address(0));

        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.assume(account != address(pool));
        vm.assume(account != pool.poolFees());

        // Given : Valid gauge
        deployAerodromeGaugeFixture(address(pool), AERO);
        vm.assume(account != address(gauge));
        vm.assume(account != address(voter));

        // And : Add asset and gauge to the AM
        stakedAerodromeAM.addAsset(address(gauge));

        {
            // And: Valid state.
            StakingAM.PositionState memory positionState;
            (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

            // And: State is persisted.
            setStakedAerodromeAMState(assetState, positionState, address(pool), 0);

            // And: updated totalStake should not be greater than uint128.
            // And: Amount staked is greater than zero.
            vm.assume(assetState.totalStaked < type(uint128).max);
            amount = uint128(bound(amount, 1, type(uint128).max - assetState.totalStaked));

            deal(address(pool), account, amount);
            approveERC20TokenFor(address(pool), address(stakedAerodromeAM), amount, account);
        }

        // When:  A user is staking via the Staking Module.
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingAM.LiquidityIncreased(1, address(pool), amount);
        uint256 positionId = stakedAerodromeAM.mint(address(pool), amount);

        // Then: Assets should have been transferred to the gauge.
        assertEq(gauge.balanceOf(address(stakedAerodromeAM)), amount);

        // And: New position has been minted to Account.
        assertEq(stakedAerodromeAM.ownerOf(positionId), account);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedAerodromeAM.positionState(positionId);
        assertEq(newPositionState.asset, address(pool));
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
            stakedAerodromeAM.assetState(address(pool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.totalStaked, assetState.totalStaked + amount);
        assertEq(stakedAerodromeAM.REWARD_TOKEN().balanceOf(address(stakedAerodromeAM)), assetState.currentRewardGlobal);
    }

    function testFuzz_Success_mint_TotalStakedForAssetIsZero(
        StakingAMStateForAsset memory assetState,
        uint128 amount,
        address account
    ) public canReceiveERC721(account) {
        vm.assume(account != address(0));

        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.assume(account != address(pool));
        vm.assume(account != pool.poolFees());

        // Given : Valid gauge
        deployAerodromeGaugeFixture(address(pool), AERO);
        vm.assume(account != address(gauge));
        vm.assume(account != address(voter));

        // And : Add asset and gauge to the AM
        stakedAerodromeAM.addAsset(address(gauge));

        // And: Valid state.
        StakingAM.PositionState memory positionState;
        (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

        // And: TotalStaked is 0.
        assetState.totalStaked = 0;

        // And: State is persisted.
        setStakedAerodromeAMState(assetState, positionState, address(pool), 0);

        // And: Amount staked is greater than zero.
        amount = uint128(bound(amount, 1, type(uint128).max));

        // And : Account has a balanceOf pool LP tokens
        deal(address(pool), account, amount);
        approveERC20TokenFor(address(pool), address(stakedAerodromeAM), amount, account);

        // When: A user is staking via the Staking Module.
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingAM.LiquidityIncreased(1, address(pool), amount);
        uint256 positionId = stakedAerodromeAM.mint(address(pool), amount);

        // Then: Assets should have been transferred to the gauge.
        assertEq(gauge.balanceOf(address(stakedAerodromeAM)), amount);

        // And: New position has been minted to Account.
        assertEq(stakedAerodromeAM.ownerOf(positionId), account);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedAerodromeAM.positionState(positionId);
        assertEq(newPositionState.asset, address(pool));
        assertEq(newPositionState.amountStaked, amount);
        assertEq(newPositionState.lastRewardPerTokenPosition, assetState.lastRewardPerTokenGlobal);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset state should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedAerodromeAM.assetState(address(pool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, amount);
    }
}
