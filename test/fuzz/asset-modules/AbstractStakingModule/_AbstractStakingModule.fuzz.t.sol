/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { AbstractStakingModule } from "../../../../src/asset-modules/staking-module/AbstractStakingModule.sol";
import { StakingModuleMock } from "../../../utils/mocks/StakingModuleMock.sol";
import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";

/**
 * @notice Common logic needed by "AbstractStakingModule" fuzz tests.
 */
abstract contract AbstractStakingModule_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct AbstractStakingModuleStateForId {
        uint128 previousRewardBalance;
        uint128 totalSupply;
        uint128 userBalance;
        uint128 rewards;
        uint128 userRewardPerTokenPaid;
        uint128 rewardPerTokenStored;
        uint128 actualRewardBalance;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    StakingModuleMock internal stakingModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);

        stakingModule = new StakingModuleMock();

        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function setStakingModuleState(
        AbstractStakingModuleStateForId memory stakingModuleState,
        uint256 id,
        address account
    ) internal returns (AbstractStakingModuleStateForId memory stakingModuleState_) {
        stakingModuleState_ = givenValidStakingModuleState(stakingModuleState);

        stakingModule.setPreviousRewardsBalance(id, stakingModuleState_.previousRewardBalance);
        stakingModule.setTotalSupply(id, stakingModuleState_.totalSupply);
        stakingModule.setRewardsForAccount(id, stakingModuleState_.rewards, account);
        stakingModule.setUserRewardPerTokenPaid(id, stakingModuleState_.userRewardPerTokenPaid, account);
        stakingModule.setRewardPerTokenStored(id, stakingModuleState_.rewardPerTokenStored);
        stakingModule.setActualRewardBalance(id, stakingModuleState_.actualRewardBalance);
        stakingModule.setBalanceOfAccountForId(id, stakingModuleState_.userBalance, account);
    }

    function givenValidStakingModuleState(AbstractStakingModuleStateForId memory stakingModuleState)
        public
        view
        returns (AbstractStakingModuleStateForId memory stakingModuleState_)
    {
        // Given : Actual reward balance should be at least equal to previousRewardBalance.
        vm.assume(stakingModuleState.actualRewardBalance >= stakingModuleState.previousRewardBalance);

        // Given : The difference between the actual and previous reward balance should be smaller than type(uint128).max / 1e18.
        vm.assume(
            stakingModuleState.actualRewardBalance - stakingModuleState.previousRewardBalance < type(uint128).max / 1e18
        );

        // Given : rewardPerTokenStored + rewardPerTokenClaimable should not be over type(uint128).max
        stakingModuleState.rewardPerTokenStored = uint128(
            bound(
                stakingModuleState.rewardPerTokenStored,
                0,
                type(uint128).max
                    - ((stakingModuleState.actualRewardBalance - stakingModuleState.previousRewardBalance) * 1e18)
            )
        );

        // Given : rewardPerTokenStored should always be >= userRewardPerTokenPaid
        vm.assume(stakingModuleState.rewardPerTokenStored >= stakingModuleState.userRewardPerTokenPaid);

        // Cache rewardPerTokenClaimable
        uint128 rewardPerTokenClaimable = stakingModuleState.rewardPerTokenStored
            + ((stakingModuleState.actualRewardBalance - stakingModuleState.previousRewardBalance) * 1e18);

        // Given : userBalance * rewardPerTokenClaimable should not be > type(uint128)
        stakingModuleState.userBalance =
            uint128(bound(stakingModuleState.userBalance, 0, (type(uint128).max) - rewardPerTokenClaimable));

        // Extra check for the above
        vm.assume(uint256(stakingModuleState.userBalance) * rewardPerTokenClaimable < type(uint128).max);

        // Given : previously earned rewards for Account + new rewards should not be > type(uint128).max.
        stakingModuleState.rewards = uint128(
            bound(
                stakingModuleState.rewards,
                0,
                type(uint128).max - (stakingModuleState.userBalance * rewardPerTokenClaimable)
            )
        );

        // Given : totalSupply should be >= to userBalance
        stakingModuleState.totalSupply =
            uint128(bound(stakingModuleState.totalSupply, stakingModuleState.userBalance, type(uint128).max));

        stakingModuleState_ = stakingModuleState;
    }

    function addStakingTokens(uint8 numberOfTokens, uint8 stakingTokenDecimals, uint8 rewardTokenDecimals)
        public
        returns (address[] memory stakingTokens, address[] memory rewardTokens)
    {
        stakingTokens = new address[](numberOfTokens);
        rewardTokens = new address[](numberOfTokens);

        stakingTokenDecimals = uint8(bound(stakingTokenDecimals, 0, 18));
        rewardTokenDecimals = uint8(bound(rewardTokenDecimals, 0, 18));

        for (uint8 i = 0; i < numberOfTokens; ++i) {
            ERC20Mock stakingToken = new ERC20Mock("StakingToken", "STK", stakingTokenDecimals);
            ERC20Mock rewardToken = new ERC20Mock("RewardToken", "RWT", rewardTokenDecimals);

            stakingTokens[i] = address(stakingToken);
            rewardTokens[i] = address(rewardToken);

            stakingModule.addNewStakingToken(address(stakingToken), address(rewardToken));
        }
    }
}
