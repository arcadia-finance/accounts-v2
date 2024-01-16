/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { StargateAssetModule } from "../../../../src/asset-modules/StargateAssetModule.sol";
import { StargateAssetModuleExtension } from "../../../utils/Extensions.sol";
import { LPStakingTimeMock } from "../../../utils/mocks/Stargate/StargateLpStakingMock.sol";
import { StargatePoolMock } from "../../../utils/mocks/Stargate/StargatePoolMock.sol";
import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";
import { ArcadiaOracle } from "../../../utils/mocks/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";

/**
 * @notice Common logic needed by "StargateAssetModule" fuzz tests.
 */
abstract contract StargateAssetModule_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    StargatePoolMock internal poolMock;
    StargateAssetModuleExtension internal stargateAssetModule;
    LPStakingTimeMock internal lpStakingTimeMock;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);

        poolMock = new StargatePoolMock(18);
        lpStakingTimeMock = new LPStakingTimeMock();
        stargateAssetModule = new StargateAssetModuleExtension(address(registryExtension), address(lpStakingTimeMock));

        registryExtension.addAssetModule(address(stargateAssetModule));
        stargateAssetModule.initialize();

        ERC20Mock rewardTokenCode = new ERC20Mock("Stargate", "STG", 18);

        vm.etch(address(stargateAssetModule.rewardToken()), address(rewardTokenCode).code);

        ArcadiaOracle stargateOracle = initMockedOracle(8, "STG / USD", rates.token1ToUsd);

        vm.startPrank(registryExtension.owner());

        chainlinkOM.addOracle(address(stargateOracle), "STG", "USD", 2 days);

        // Add STG to the standardERC20AssetModule
        uint80[] memory oracleStgToUsdArr = new uint80[](1);
        oracleStgToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(stargateOracle)));

        erc20AssetModule.addAsset(
            address(stargateAssetModule.rewardToken()), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleStgToUsdArr)
        );

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
        stakingModuleStateForPosition.asset = asset;
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

        // Given : totalStaked should be >= to amountStakedForPosition
        stakingModuleStateForAsset.totalStaked = uint128(
            bound(stakingModuleStateForAsset.totalStaked, stakingModuleStateForPosition.amountStaked, type(uint128).max)
        );

        stakingModuleStateForAsset_ = stakingModuleStateForAsset;
        stakingModuleStateForPosition_ = stakingModuleStateForPosition;
    }
}
