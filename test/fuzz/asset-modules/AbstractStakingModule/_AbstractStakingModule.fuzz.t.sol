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

    struct StakingModuleStateForAsset {
        uint128 currentRewardGlobal;
        uint128 lastRewardPerTokenGlobal;
        uint128 lastRewardGlobal;
        uint128 totalStaked;
    }

    struct StakingModuleStateForPosition {
        address owner;
        address asset;
        uint128 amountStaked;
        uint128 lastRewardPerTokenPosition;
        uint128 lastRewardPosition;
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
        StakingModuleStateForAsset memory stakingModuleStateForAsset,
        StakingModule.PositionState memory stakingModuleStateForPosition,
        address asset,
        uint256 id
    )
        internal
        returns (
            StakingModuleStateForAsset memory stakingModuleStateForAsset_,
            StakingModule.PositionState memory stakingModuleStateForPosition_
        )
    {
        (stakingModuleStateForAsset_, stakingModuleStateForPosition_) =
            givenValidStakingModuleState(stakingModuleStateForAsset, stakingModuleStateForPosition);

        stakingModule.setLastRewardGlobal(asset, stakingModuleStateForAsset_.lastRewardGlobal);
        stakingModule.setTotalStaked(asset, stakingModuleStateForAsset_.totalStaked);
        stakingModule.setLastRewardPosition(id, stakingModuleStateForPosition_.lastRewardPosition);
        stakingModule.setLastRewardPerTokenPosition(id, stakingModuleStateForPosition_.lastRewardPerTokenPosition);
        stakingModule.setLastRewardPerTokenGlobal(asset, stakingModuleStateForAsset_.lastRewardPerTokenGlobal);
        stakingModule.setActualRewardBalance(asset, stakingModuleStateForAsset_.currentRewardGlobal);
        stakingModule.setAmountStakedForPosition(id, stakingModuleStateForPosition_.amountStaked);
        stakingModule.setAssetInPosition(asset, id);
    }

    function givenValidStakingModuleState(
        StakingModuleStateForAsset memory stakingModuleStateForAsset,
        StakingModule.PositionState memory stakingModuleStateForPosition
    )
        public
        view
        returns (
            StakingModuleStateForAsset memory stakingModuleStateForAsset_,
            StakingModule.PositionState memory stakingModuleStateForPosition_
        )
    {
        // Given : Actual reward balance should be at least equal to lastRewardGlobal.
        vm.assume(stakingModuleStateForAsset.currentRewardGlobal >= stakingModuleStateForAsset.lastRewardGlobal);

        // Given : The difference between the actual and previous reward balance should be smaller than type(uint128).max / 1e18.
        vm.assume(
            stakingModuleStateForAsset.currentRewardGlobal - stakingModuleStateForAsset.lastRewardGlobal
                < type(uint128).max / 1e18
        );

        // Given : lastRewardPerTokenGlobal + rewardPerTokenClaimable should not be over type(uint128).max
        stakingModuleStateForAsset.lastRewardPerTokenGlobal = uint128(
            bound(
                stakingModuleStateForAsset.lastRewardPerTokenGlobal,
                0,
                type(uint128).max
                    - (
                        (stakingModuleStateForAsset.currentRewardGlobal - stakingModuleStateForAsset.lastRewardGlobal)
                            * 1e18
                    )
            )
        );

        // Given : lastRewardPerTokenGlobal should always be >= lastRewardPerTokenPosition
        vm.assume(
            stakingModuleStateForAsset.lastRewardPerTokenGlobal
                >= stakingModuleStateForPosition.lastRewardPerTokenPosition
        );

        // Cache rewardPerTokenClaimable
        uint128 rewardPerTokenClaimable = stakingModuleStateForAsset.lastRewardPerTokenGlobal
            + ((stakingModuleStateForAsset.currentRewardGlobal - stakingModuleStateForAsset.lastRewardGlobal) * 1e18);

        // Given : amountStaked * rewardPerTokenClaimable should not be > type(uint128)
        stakingModuleStateForPosition.amountStaked =
            uint128(bound(stakingModuleStateForPosition.amountStaked, 0, (type(uint128).max) - rewardPerTokenClaimable));

        // Extra check for the above
        vm.assume(uint256(stakingModuleStateForPosition.amountStaked) * rewardPerTokenClaimable < type(uint128).max);

        // Given : previously earned rewards for Account + new rewards should not be > type(uint128).max.
        stakingModuleStateForPosition.lastRewardPosition = uint128(
            bound(
                stakingModuleStateForPosition.lastRewardPosition,
                0,
                type(uint128).max - (stakingModuleStateForPosition.amountStaked * rewardPerTokenClaimable)
            )
        );

        // Given : totalSupply should be >= to amountStakedForId
        stakingModuleStateForAsset.totalStaked = uint128(
            bound(stakingModuleStateForAsset.totalStaked, stakingModuleStateForPosition.amountStaked, type(uint128).max)
        );

        stakingModuleStateForAsset_ = stakingModuleStateForAsset;
        stakingModuleStateForPosition_ = stakingModuleStateForPosition;
    }

    function addAssets(uint8 numberOfAssets, uint8 assetDecimals, uint8 rewardTokenDecimals)
        public
        returns (address[] memory assets, address[] memory rewardTokens)
    {
        assets = new address[](numberOfAssets);
        rewardTokens = new address[](numberOfAssets);

        assetDecimals = uint8(bound(assetDecimals, 0, 18));
        rewardTokenDecimals = uint8(bound(rewardTokenDecimals, 0, 18));

        for (uint8 i = 0; i < numberOfAssets; ++i) {
            ERC20Mock asset = new ERC20Mock("Asset", "AST", assetDecimals);
            ERC20Mock rewardToken = new ERC20Mock("RewardToken", "RWT", rewardTokenDecimals);

            assets[i] = address(asset);
            rewardTokens[i] = address(rewardToken);

            stakingModule.setAssetAndRewardToken(address(asset), rewardToken);
        }
    }
}
