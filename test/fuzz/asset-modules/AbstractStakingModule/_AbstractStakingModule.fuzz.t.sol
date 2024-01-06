/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { StakingModule } from "../../../../src/asset-modules/staking-module/AbstractStakingModule.sol";
import { StakingModuleMock } from "../../../utils/mocks/StakingModuleMock.sol";
import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";

/**
 * @notice Common logic needed by "StakingModule" fuzz tests.
 */
abstract contract AbstractStakingModule_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct StakingModuleStateForId {
        uint128 currentRewardGlobal;
        uint128 lastRewardPerTokenGlobal;
        uint128 lastRewardGlobal;
        uint128 totalSupply;
        uint128 lastRewardPerTokenAccount;
        uint128 lastRewardAccount;
        uint128 accountBalance;
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

    function setStakingModuleState(StakingModuleStateForId memory stakingModuleState, uint256 id, address account)
        internal
        returns (StakingModuleStateForId memory stakingModuleState_)
    {
        stakingModuleState_ = givenValidStakingModuleState(stakingModuleState);

        stakingModule.setLastRewardGlobal(id, stakingModuleState_.lastRewardGlobal);
        stakingModule.setTotalSupply(id, stakingModuleState_.totalSupply);
        stakingModule.setLastRewardAccount(id, stakingModuleState_.lastRewardAccount, account);
        stakingModule.setLastRewardPerTokenAccount(id, stakingModuleState_.lastRewardPerTokenAccount, account);
        stakingModule.setLastRewardPerTokenGlobal(id, stakingModuleState_.lastRewardPerTokenGlobal);
        stakingModule.setActualRewardBalance(id, stakingModuleState_.currentRewardGlobal);
        stakingModule.setBalanceOf(id, stakingModuleState_.accountBalance, account);
    }

    function givenValidStakingModuleState(StakingModuleStateForId memory stakingModuleState)
        public
        view
        returns (StakingModuleStateForId memory stakingModuleState_)
    {
        // Given : Actual reward balance should be at least equal to lastRewardGlobal.
        vm.assume(stakingModuleState.currentRewardGlobal >= stakingModuleState.lastRewardGlobal);

        // Given : The difference between the actual and previous reward balance should be smaller than type(uint128).max / 1e18.
        vm.assume(
            stakingModuleState.currentRewardGlobal - stakingModuleState.lastRewardGlobal < type(uint128).max / 1e18
        );

        // Given : lastRewardPerTokenGlobal + rewardPerTokenClaimable should not be over type(uint128).max
        stakingModuleState.lastRewardPerTokenGlobal = uint128(
            bound(
                stakingModuleState.lastRewardPerTokenGlobal,
                0,
                type(uint128).max
                    - ((stakingModuleState.currentRewardGlobal - stakingModuleState.lastRewardGlobal) * 1e18)
            )
        );

        // Given : lastRewardPerTokenGlobal should always be >= lastRewardPerTokenAccount
        vm.assume(stakingModuleState.lastRewardPerTokenGlobal >= stakingModuleState.lastRewardPerTokenAccount);

        // Cache rewardPerTokenClaimable
        uint128 rewardPerTokenClaimable = stakingModuleState.lastRewardPerTokenGlobal
            + ((stakingModuleState.currentRewardGlobal - stakingModuleState.lastRewardGlobal) * 1e18);

        // Given : accountBalance * rewardPerTokenClaimable should not be > type(uint128)
        stakingModuleState.accountBalance =
            uint128(bound(stakingModuleState.accountBalance, 0, (type(uint128).max) - rewardPerTokenClaimable));

        // Extra check for the above
        vm.assume(uint256(stakingModuleState.accountBalance) * rewardPerTokenClaimable < type(uint128).max);

        // Given : previously earned rewards for Account + new rewards should not be > type(uint128).max.
        stakingModuleState.lastRewardAccount = uint128(
            bound(
                stakingModuleState.lastRewardAccount,
                0,
                type(uint128).max - (stakingModuleState.accountBalance * rewardPerTokenClaimable)
            )
        );

        // Given : totalSupply should be >= to accountBalance
        stakingModuleState.totalSupply =
            uint128(bound(stakingModuleState.totalSupply, stakingModuleState.accountBalance, type(uint128).max));

        stakingModuleState_ = stakingModuleState;
    }

    function addStakingTokens(uint8 numberOfTokens, uint8 underlyingTokenDecimals, uint8 rewardTokenDecimals)
        public
        returns (address[] memory underlyingTokens, address[] memory rewardTokens)
    {
        underlyingTokens = new address[](numberOfTokens);
        rewardTokens = new address[](numberOfTokens);

        underlyingTokenDecimals = uint8(bound(underlyingTokenDecimals, 0, 18));
        rewardTokenDecimals = uint8(bound(rewardTokenDecimals, 0, 18));

        for (uint8 i = 0; i < numberOfTokens; ++i) {
            ERC20Mock underlyingToken = new ERC20Mock("UnderlyingToken", "UTK", underlyingTokenDecimals);
            ERC20Mock rewardToken = new ERC20Mock("RewardToken", "RWT", rewardTokenDecimals);

            underlyingTokens[i] = address(underlyingToken);
            rewardTokens[i] = address(rewardToken);

            stakingModule.addNewStakingToken(address(underlyingToken), address(rewardToken));
        }
    }
}
