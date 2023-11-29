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
    }

    struct AbstractStakingModuleState {
        uint256 idCounter;
        address stakingToken;
        address rewardToken;
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

    
}
