/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { StakingRewardsMock } from "../../../utils/mocks/StakingRewardsMock.sol";
import { StakingModuleMock } from "../../../utils/mocks/StakingModuleMock.sol";

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
        uint256 previousRewardBalance;
        uint256 totalSupply;
        uint256 rewards;
        uint256 userRewardPerTokenPaid;
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

        stakingModule = new StakingModuleMock(address(factory));
        stakingRewardsContract = new StakingRewardsMock();

        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function setStakingRewardsContractState(StakingRewardsContractState memory rewardState, address account) internal {
        stakingRewardsContract.setStakingRewardsState(
            rewardState.rewards, account, rewardState.totalSupply, rewardState.balance, rewardState.rewardPerTokenStored
        );
    }

    function setStakingModuleState(
        AbstractStakingModuleStateForId memory stakingModuleStateForId,
        uint256 id,
        address account
    ) internal {
        stakingModule.setPreviousRewardsBalance(id, stakingModuleStateForId.previousRewardBalance);
        stakingModule.setTotalSupply(id, stakingModuleStateForId.totalSupply);
        stakingModule.setRewardsForAccount(id, stakingModuleStateForId.rewards, account);
        stakingModule.setUserRewardPerTokenPaid(id, stakingModuleStateForId.userRewardPerTokenPaid, account);
    }
}
