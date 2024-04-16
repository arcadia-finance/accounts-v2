/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { WrappedAM } from "../../../../src/asset-modules/abstracts/AbstractWrappedAM.sol";
import { WrappedAMMock } from "../../../utils/mocks/asset-modules/WrappedAMMock.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";

/**
 * @notice Common logic needed by "WrappedAM" fuzz tests.
 */
abstract contract AbstractWrappedAM_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct WrappedAMAssetAndRewardStateGlobal {
        uint256 currentRewardGlobal;
        uint128 lastRewardPerTokenGlobal;
    }

    struct WrappedAMPositionState {
        address customAsset;
        uint128 amountWrapped;
    }

    struct WrappedAMPositionStatePerReward {
        uint128 lastRewardPerTokenPosition;
        uint128 lastRewardPosition;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    WrappedAMMock internal wrappedAM;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);
        wrappedAM = new WrappedAMMock(address(registryExtension), "WrappedAMTest", "WMT");
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function setWrappedAMState(
        WrappedAMAssetAndRewardStateGlobal[] memory assetAndRewardState,
        WrappedAMPositionState memory positionState,
        WrappedAMPositionStatePerReward[] memory positionStatePerReward,
        address asset,
        address[] memory rewards,
        uint96 tokenId,
        uint128 totalWrapped,
        address underlyingAsset
    ) internal returns (address customAsset) {
        customAsset = getCustomAsset(asset, rewards);

        wrappedAM.setCustomAssetInfo(customAsset, asset, rewards);
        wrappedAM.setTotalWrapped(asset, totalWrapped);
        wrappedAM.setAmountWrappedForPosition(tokenId, positionState.amountWrapped);
        wrappedAM.setCustomAssetForPosition(customAsset, tokenId);
        wrappedAM.setRewardsForAsset(asset, rewards);
        wrappedAM.setAssetToUnderlyingAsset(asset, underlyingAsset);

        // Set all state info per reward token
        for (uint256 i; i < rewards.length; ++i) {
            wrappedAM.setLastRewardPosition(tokenId, rewards[i], positionStatePerReward[i].lastRewardPosition);
            wrappedAM.setLastRewardPerTokenPosition(
                tokenId, rewards[i], positionStatePerReward[i].lastRewardPerTokenPosition
            );
            wrappedAM.setLastRewardPerTokenGlobal(asset, rewards[i], assetAndRewardState[i].lastRewardPerTokenGlobal);
            wrappedAM.setCurrentRewardBalance(asset, rewards[i], assetAndRewardState[i].currentRewardGlobal);
        }
    }

    function givenValidWrappedAMState(
        WrappedAMAssetAndRewardStateGlobal[] memory assetAndRewardState,
        WrappedAMPositionState memory positionState,
        WrappedAMPositionStatePerReward[] memory positionStatePerReward,
        uint128 totalWrapped
    )
        public
        view
        returns (
            WrappedAMAssetAndRewardStateGlobal[] memory,
            WrappedAMPositionState memory,
            WrappedAMPositionStatePerReward[] memory,
            uint128
        )
    {
        // Given: More than 1 gwei is staked.
        totalWrapped = uint128(bound(totalWrapped, 1, type(uint128).max));

        // And: totalWrapped should be >= to amountWrapped for position (invariant).
        positionState.amountWrapped = uint128(bound(positionState.amountWrapped, 0, totalWrapped));

        for (uint256 i; i < assetAndRewardState.length; ++i) {
            // And: deltaRewardPerToken is smaller or equal as type(uint128).max (no overflow safeCastTo128). TODO: double check
            assetAndRewardState[i].currentRewardGlobal =
                bound(assetAndRewardState[i].currentRewardGlobal, 1, uint256(type(uint128).max) * totalWrapped / 1e18);

            // Calculate the new rewardPerTokenGlobal
            uint256 deltaRewardPerToken = assetAndRewardState[i].currentRewardGlobal * 1e18 / totalWrapped;
            uint128 currentRewardPerTokenGlobal;
            unchecked {
                currentRewardPerTokenGlobal =
                    assetAndRewardState[i].lastRewardPerTokenGlobal + uint128(deltaRewardPerToken);
            }

            // And: Previously earned rewards for Account + new rewards does not overflow.
            // -> deltaReward of the position is smaller or equal to type(uint128).max (overflow).
            // -> deltaRewardPerToken * positionState_.amountStaked / 1e18 <= type(uint128).max;
            unchecked {
                deltaRewardPerToken = currentRewardPerTokenGlobal - positionStatePerReward[i].lastRewardPerTokenPosition;
            }
            if (positionState.amountWrapped > 0) {
                deltaRewardPerToken = uint128(
                    bound(deltaRewardPerToken, 0, type(uint128).max * uint256(1e18) / positionState.amountWrapped)
                );
            }
            unchecked {
                positionStatePerReward[i].lastRewardPerTokenPosition =
                    currentRewardPerTokenGlobal - uint128(deltaRewardPerToken);
            }
            uint256 deltaReward = deltaRewardPerToken * uint256(positionState.amountWrapped) / 1e18;

            // And: Previously earned rewards for Account + new rewards does not overflow.
            // -> lastRewardPosition + deltaReward <= type(uint128).max;
            positionStatePerReward[i].lastRewardPosition =
                uint128(bound(positionStatePerReward[i].lastRewardPosition, 0, type(uint128).max - deltaReward));
        }

        return (assetAndRewardState, positionState, positionStatePerReward, totalWrapped);
    }

    function addAsset(uint8 assetDecimals, uint8 rewardDecimals, uint8 numberOfRewards)
        public
        returns (address asset_, address[] memory rewards_)
    {
        assetDecimals = uint8(bound(assetDecimals, 0, 18));
        rewardDecimals = uint8(bound(assetDecimals, 0, 18));
        asset_ = address(new ERC20Mock("Asset", "AST", assetDecimals));

        rewards_ = new address[](numberOfRewards);
        for (uint256 i; i < numberOfRewards; ++i) {
            rewards_[i] = address(new ERC20Mock("Reward", "RWD", rewardDecimals));
        }

        address customAsset = getCustomAsset(asset_, rewards_);
        wrappedAM.addAsset(customAsset, asset_, rewards_);
    }

    function getCustomAsset(address asset, address[] memory rewards) public pure returns (address customAsset) {
        customAsset = address(uint160(uint256(keccak256(abi.encodePacked(asset, rewards)))));
    }

    function castArrayStaticToDynamicAssetAndReward(WrappedAMAssetAndRewardStateGlobal[2] memory staticArray)
        public
        pure
        returns (WrappedAMAssetAndRewardStateGlobal[] memory dynamicArray)
    {
        uint256 length = staticArray.length;
        dynamicArray = new WrappedAMAssetAndRewardStateGlobal[](length);

        for (uint256 i; i < length;) {
            dynamicArray[i] = staticArray[i];

            unchecked {
                ++i;
            }
        }
    }

    function castArrayStaticToDynamicPositionPerReward(WrappedAMPositionStatePerReward[2] memory staticArray)
        public
        pure
        returns (WrappedAMPositionStatePerReward[] memory dynamicArray)
    {
        uint256 length = staticArray.length;
        dynamicArray = new WrappedAMPositionStatePerReward[](length);

        for (uint256 i; i < length;) {
            dynamicArray[i] = staticArray[i];

            unchecked {
                ++i;
            }
        }
    }
}
