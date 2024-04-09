/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { Pool } from "../../../utils/fixtures/aerodrome/AeroPoolFixture.f.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

/**
 * @notice Fuzz tests for the function "mint" of contract "WrappedAerodromeAM".
 */
contract Mint_WrappedAerodromeAM_Fuzz_Test is WrappedAerodromeAM_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        WrappedAerodromeAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS 
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_mint_ZeroAmount(address pool_) public {
        // The stake function should revert when trying to stake 0 amount.
        vm.expectRevert(WrappedAerodromeAM.ZeroAmount.selector);
        wrappedAerodromeAM.mint(pool_, 0);
    }

    function testFuzz_Revert_mint_PoolNotAllowed(uint128 amount, bool stable, address account) public {
        // Given : Amount is greater than zero
        vm.assume(amount > 0);

        // Given : Valid pool
        pool = Pool(poolFactory.createPool(address(asset0), address(asset1), stable));

        // When : Calling Stake
        // Then : The function should revert as the asset has not been added to the Staking Module.
        vm.prank(account);
        vm.expectRevert(WrappedAerodromeAM.PoolNotAllowed.selector);
        wrappedAerodromeAM.mint(address(pool), amount);
    }

    // function testFuzz_Success_mint_TotalStakedForAssetGreaterThan0(
    //     uint8 assetDecimals,
    //     StakingAMStateForAsset memory poolState,
    //     uint128 amount,
    //     address account
    // ) public notTestContracts(account) {
    //     vm.assume(account != address(0));
    //     vm.assume(account != address(wrappedAerodromeAM));
    //     vm.assume(account != address(rewardToken));

    //     address asset;
    //     {
    //         // Given: An Asset is added to the wrappedAerodromeAM.
    //         asset = addAsset(assetDecimals);
    //         vm.assume(account != asset);

    //         // And: Valid state.
    //         StakingAM.PositionState memory positionState;
    //         (poolState, positionState) = givenValidStakingAMState(poolState, positionState);

    //         // And: State is persisted.
    //         setStakingAMState(poolState, positionState, asset, 0);

    //         // And: updated totalStake should not be greater than uint128.
    //         // And: Amount staked is greater than zero.
    //         vm.assume(poolState.totalStaked < type(uint128).max);
    //         amount = uint128(bound(amount, 1, type(uint128).max - poolState.totalStaked));

    //         address[] memory tokens = new address[](1);
    //         tokens[0] = asset;

    //         uint256[] memory amounts = new uint256[](1);
    //         amounts[0] = amount;

    //         mintERC20TokensTo(tokens, account, amounts);
    //         approveERC20TokensFor(tokens, address(wrappedAerodromeAM), amounts, account);
    //     }

    //     // When:  A user is staking via the Staking Module.
    //     vm.startPrank(account);
    //     vm.expectEmit();
    //     emit StakingAM.LiquidityIncreased(1, asset, amount);
    //     uint256 positionId = wrappedAerodromeAM.mint(asset, amount);

    //     // Then: Assets should have been transferred to the Staking Module.
    //     assertEq(ERC20Mock(asset).balanceOf(address(wrappedAerodromeAM)), amount);

    //     // And: New position has been minted to Account.
    //     assertEq(wrappedAerodromeAM.ownerOf(positionId), account);

    //     // And: Position state should be updated correctly.
    //     StakingAM.PositionState memory newPositionState;
    //     (
    //         newPositionState.asset,
    //         newPositionState.amountStaked,
    //         newPositionState.lastRewardPerTokenPosition,
    //         newPositionState.lastRewardPosition
    //     ) = wrappedAerodromeAM.positionState(positionId);
    //     assertEq(newPositionState.asset, asset);
    //     assertEq(newPositionState.amountStaked, amount);
    //     uint128 currentRewardPerToken;
    //     unchecked {
    //         currentRewardPerToken = poolState.lastRewardPerTokenGlobal
    //             + uint128(poolState.currentRewardGlobal.mulDivDown(1e18, poolState.totalStaked));
    //     }
    //     assertEq(newPositionState.lastRewardPerTokenPosition, currentRewardPerToken);
    //     assertEq(newPositionState.lastRewardPosition, 0);

    //     // And: Asset state should be updated correctly.
    //     StakingAM.PoolState memory newPoolState;
    //     (newPoolState.lastRewardPerTokenGlobal, newPoolState.totalStaked,) = wrappedAerodromeAM.poolState(asset);
    //     assertEq(newPoolState.lastRewardPerTokenGlobal, currentRewardPerToken);
    //     assertEq(newPoolState.totalStaked, poolState.totalStaked + amount);
    // }

    // function testFuzz_Success_mint_TotalStakedForAssetIsZero(
    //     uint8 assetDecimals,
    //     StakingAMStateForAsset memory poolState,
    //     uint128 amount,
    //     address account
    // ) public notTestContracts(account) {
    //     vm.assume(account != address(0));
    //     vm.assume(account != address(wrappedAerodromeAM));
    //     vm.assume(account != address(rewardToken));

    //     // Given: An Asset is added to the wrappedAerodromeAM.
    //     address asset = addAsset(assetDecimals);
    //     vm.assume(account != asset);

    //     // And: Valid state.
    //     StakingAM.PositionState memory positionState;
    //     (poolState, positionState) = givenValidStakingAMState(poolState, positionState);

    //     // And: TotalStaked is 0.
    //     poolState.totalStaked = 0;

    //     // And: State is persisted.
    //     setStakingAMState(poolState, positionState, asset, 0);

    //     // And: Amount staked is greater than zero.
    //     amount = uint128(bound(amount, 1, type(uint128).max));

    //     address[] memory tokens = new address[](1);
    //     tokens[0] = asset;

    //     uint256[] memory amounts = new uint256[](1);
    //     amounts[0] = amount;

    //     mintERC20TokensTo(tokens, account, amounts);
    //     approveERC20TokensFor(tokens, address(wrappedAerodromeAM), amounts, account);

    //     // When:  A user is staking via the Staking Module.
    //     vm.startPrank(account);
    //     vm.expectEmit();
    //     emit StakingAM.LiquidityIncreased(1, asset, amount);
    //     uint256 positionId = wrappedAerodromeAM.mint(asset, amount);

    //     // Then: Assets should have been transferred to the Staking Module.
    //     assertEq(ERC20Mock(asset).balanceOf(address(wrappedAerodromeAM)), amount);

    //     // And: New position has been minted to Account.
    //     assertEq(wrappedAerodromeAM.ownerOf(positionId), account);

    //     // And: Position state should be updated correctly.
    //     StakingAM.PositionState memory newPositionState;
    //     (
    //         newPositionState.asset,
    //         newPositionState.amountStaked,
    //         newPositionState.lastRewardPerTokenPosition,
    //         newPositionState.lastRewardPosition
    //     ) = wrappedAerodromeAM.positionState(positionId);
    //     assertEq(newPositionState.asset, asset);
    //     assertEq(newPositionState.amountStaked, amount);
    //     assertEq(newPositionState.lastRewardPerTokenPosition, poolState.lastRewardPerTokenGlobal);
    //     assertEq(newPositionState.lastRewardPosition, 0);

    //     // And: Asset state should be updated correctly.
    //     StakingAM.PoolState memory newPoolState;
    //     (newPoolState.lastRewardPerTokenGlobal, newPoolState.totalStaked,) = wrappedAerodromeAM.poolState(asset);
    //     assertEq(newPoolState.lastRewardPerTokenGlobal, poolState.lastRewardPerTokenGlobal);
    //     assertEq(newPoolState.totalStaked, amount);
    // }
}
