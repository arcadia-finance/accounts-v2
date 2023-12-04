/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { StakingRewardsMock } from "../../../utils/mocks/StakingRewardsMock.sol";
import { StakingModuleMock } from "../../../utils/mocks/StakingModuleMock.sol";
import { StakingModuleErrors } from "../../../../src/libraries/Errors.sol";
import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";

/**
 * @notice Common logic needed by "AbstractStakingModule" fuzz tests.
 */
abstract contract AbstractStakingModule_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct StakingRewardsContractState {
        uint256 totalSupply;
        uint256 rewards;
        uint256 balance;
        uint256 rewardPerTokenStored;
    }

    struct AbstractStakingModuleStateForId {
        uint128 previousRewardBalance;
        uint256 totalSupply;
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
    StakingRewardsMock internal stakingRewardsContract;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);

        stakingModule = new StakingModuleMock();
        stakingRewardsContract = new StakingRewardsMock();

        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    // Note: don't think we need this one for the abstract module testing
    function setStakingRewardsContractState(StakingRewardsContractState memory rewardState, address account) internal {
        stakingRewardsContract.setStakingRewardsState(
            rewardState.rewards, account, rewardState.totalSupply, rewardState.balance, rewardState.rewardPerTokenStored
        );
    }

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
        // Given : rewardPerTokenStored should be >= to userRewardPerTokenPaid.
        stakingModuleState.rewardPerTokenStored = uint128(
            bound(stakingModuleState.rewardPerTokenStored, stakingModuleState.userRewardPerTokenPaid, type(uint128).max)
        );

        // Given : previousRewardBalance should be smaller than type(uint128).max.
        stakingModuleState.previousRewardBalance =
            uint128(bound(stakingModuleState.previousRewardBalance, 0, type(uint128).max));

        // Given : Actual reward balance should be at least equal to previousRewardBalance.
        vm.assume(stakingModuleState.actualRewardBalance >= stakingModuleState.previousRewardBalance);

        // Given : The difference between the actual and previous reward balance should be smaller than type(uint128).max / 1e18.
        vm.assume(
            stakingModuleState.actualRewardBalance - stakingModuleState.previousRewardBalance < type(uint128).max / 1e18
        );

        // Given : totalSupply should be >= to userBalance
        stakingModuleState.totalSupply =
            bound(stakingModuleState.totalSupply, stakingModuleState.userBalance, type(uint256).max);

        stakingModuleState_ = stakingModuleState;
    }

    function addStakingTokens(uint8 numberOfTokens, uint8 stakingTokenDecimals, uint8 rewardTokenDecimals)
        public
        returns (address[] memory stakingTokens, address[] memory rewardTokens)
    {
        stakingTokens = new address[](numberOfTokens);
        rewardTokens = new address[](numberOfTokens);

        stakingTokenDecimals = uint8(bound(stakingTokenDecimals, 6, 18));
        rewardTokenDecimals = uint8(bound(rewardTokenDecimals, 6, 18));

        for (uint8 i = 0; i < numberOfTokens; ++i) {
            ERC20Mock stakingToken = new ERC20Mock("StakingToken", "STK", stakingTokenDecimals);
            ERC20Mock rewardToken = new ERC20Mock("RewardToken", "RWT", rewardTokenDecimals);

            stakingTokens[i] = address(stakingToken);
            rewardTokens[i] = address(rewardToken);

            stakingModule.addNewStakingToken(address(stakingToken), address(rewardToken));
        }
    }
}
