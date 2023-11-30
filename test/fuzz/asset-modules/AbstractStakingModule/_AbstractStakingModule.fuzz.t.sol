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

        stakingModule = new StakingModuleMock();
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

    function addStakingTokens(uint8 numberOfTokens, uint8 stakingTokenDecimals, uint8 rewardTokenDecimals)
        public
        returns (address[] memory stakingTokens, address[] memory rewardTokens)
    {
        stakingTokens = new address[](numberOfTokens);
        rewardTokens = new address[](numberOfTokens);

        for (uint8 i = 0; i < numberOfTokens; ++i) {
            ERC20Mock stakingToken = new ERC20Mock("StakingToken", "STK", stakingTokenDecimals);
            ERC20Mock rewardToken = new ERC20Mock("RewardToken", "RWT", rewardTokenDecimals);

            stakingTokens[i] = address(stakingToken);
            rewardTokens[i] = address(rewardToken);

            stakingModule.addNewStakingToken(address(stakingToken), address(rewardToken));
        }
    }

    function mintTokenTo(address token, address to, uint256 amount) public {
        ERC20Mock(token).mint(to, amount);
    }

    function mintTokensTo(address[] memory tokens, address to, uint256[] memory amounts) public {
        for (uint8 i = 0; i < tokens.length; ++i) {
            ERC20Mock(tokens[i]).mint(to, amounts[i]);
        }
    }

    function approveTokenFor(address token, address spender, uint256 amount, address user) public {
        vm.prank(user);
        ERC20Mock(token).approve(spender, amount);
    }

    function approveTokensFor(address[] memory tokens, address spender, uint256[] memory amounts, address user)
        public
    {
        vm.startPrank(user);
        for (uint8 i = 0; i < tokens.length; ++i) {
            ERC20Mock(tokens[i]).approve(spender, amounts[i]);
        }
        vm.stopPrank();
    }
}
