/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, StakingModule, ERC20Mock } from "./_AbstractStakingModule.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "stake" of contract "StakingModule".
 */
contract Stake_AbstractAbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_stake_ZeroAmount(address asset, address receiver) public {
        // The stake function should revert when trying to stake 0 amount.
        vm.expectRevert(StakingModule.ZeroAmount.selector);
        stakingModule.stake(0, asset, 0, receiver);
    }

    function testFuzz_Success_stake(uint128 amount, address staker, uint8 assetDecimals, uint8 rewardTokenDecimals)
        public
        notTestContracts(staker)
    {
        // Given : Can't stake zero amount
        vm.assume(amount > 0);

        // Given : Two staking tokens are added to the stakingModule
        (address[] memory assets,) = addAssets(2, assetDecimals, rewardTokenDecimals);
        address asset1 = assets[0];
        address asset2 = assets[1];

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;

        mintERC20TokensTo(assets, staker, amounts);
        approveERC20TokensFor(assets, address(stakingModule), amounts, staker);

        // When :  A user is staking via the Staking Module
        vm.startPrank(staker);
        vm.expectEmit();
        emit StakingModule.Staked(staker, asset1, amount);
        stakingModule.stake(0, asset1, amount, staker);
        vm.expectEmit();
        emit StakingModule.Staked(staker, asset2, amount);
        stakingModule.stake(0, asset2, amount, staker);
        vm.stopPrank();

        // Then : Tokens should be transferred to the module and specific ERC1155 minted
        (,, uint128 amountStakedId1,,) = stakingModule.positionState(1);
        (,, uint128 amountStakedId2,,) = stakingModule.positionState(2);
        assertEq(amountStakedId1, amount);
        assertEq(amountStakedId2, amount);
        assertEq(ERC20Mock(asset1).balanceOf(address(stakingModule)), amount);
        assertEq(ERC20Mock(asset2).balanceOf(address(stakingModule)), amount);
        (,, uint128 totalStakedAsset1) = stakingModule.assetState(asset1);
        (,, uint128 totalStakedAsset2) = stakingModule.assetState(asset2);
        assertEq(totalStakedAsset1, amount);
        assertEq(totalStakedAsset2, amount);
    }
}
