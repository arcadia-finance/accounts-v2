/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";
import { WrappedAM } from "../../../src/asset-modules/abstracts/AbstractWrappedAM.sol";

abstract contract WrappedAMExtension is WrappedAM {
    constructor(address registry, string memory name_, string memory symbol_) WrappedAM(registry, name_, symbol_) { }

    function setCustomAssetForPosition(address customAsset_, uint96 tokenId) public {
        positionState[tokenId].customAsset = customAsset_;
    }

    function addAsset(address asset, address[] memory rewards) public returns (address customAsset) {
        customAsset = _addAsset(asset, rewards);
    }

    function isRewardPresent(address[] memory currentRewardsForAsset, address reward) public pure returns (bool) {
        return _isRewardPresent(currentRewardsForAsset, reward);
    }

    function setCustomAssetInfo(address customAsset, address asset_, address[] memory rewards_) public {
        customAssetInfo[customAsset] = WrappedAM.AssetAndRewards({ allowed: true, asset: asset_, rewards: rewards_ });
    }

    function setCustomAssetNotAllowed(address customAsset) public {
        customAssetInfo[customAsset].allowed = false;
    }

    function setAssetToUnderlyingAsset(address asset, address underlyingAsset) public {
        assetToUnderlyingAsset[asset] = underlyingAsset;
    }

    function setAmountWrappedForPosition(uint256 id, uint256 amount) public {
        positionState[id].amountWrapped = uint128(amount);
    }

    function setTotalWrapped(address asset, uint128 totalWrapped_) public {
        assetToTotalWrapped[asset] = totalWrapped_;
    }

    function setLastRewardPerTokenGlobal(address asset, address reward, uint128 amount) public {
        lastRewardPerTokenGlobal[asset][reward] = amount;
    }

    function setLastRewardPosition(uint256 id, address reward, uint128 amount) public {
        rewardStatePosition[id][reward].lastRewardPosition = amount;
    }

    function setLastRewardPerTokenPosition(uint256 id, address reward, uint128 amount) public {
        rewardStatePosition[id][reward].lastRewardPerTokenPosition = amount;
    }

    function getIdCounter() public view returns (uint256 lastId_) {
        lastId_ = lastPositionId;
    }

    function setIdCounter(uint256 lastId_) public {
        lastPositionId = lastId_;
    }

    function setOwnerOfPositionId(address owner_, uint256 positionId) public {
        _ownerOf[positionId] = owner_;
    }

    function setRewardsForAsset(address asset, address[] memory rewards) public {
        rewardsForAsset[asset] = rewards;
    }

    function getRewardBalances(uint256 positionId)
        public
        view
        returns (
            uint128[] memory lastRewardPerTokenGlobalArr,
            RewardStatePosition[] memory rewardStatePositionArr,
            address[] memory activeRewards_
        )
    {
        (lastRewardPerTokenGlobalArr, rewardStatePositionArr, activeRewards_) = _getRewardBalances(positionId);
    }

    function mintIdTo(address to, uint256 tokenId) public {
        _safeMint(to, tokenId);
    }

    function getAssetFromKey(bytes32 key) public view returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public view returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }

    function getUnderlyingAssets(bytes32 assetKey) public view returns (bytes32[] memory underlyingAssetKeys) {
        underlyingAssetKeys = _getUnderlyingAssets(assetKey);
    }

    function getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256 assetAmount,
        bytes32[] memory underlyingAssetKeys
    )
        public
        view
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) =
            _getUnderlyingAssetsAmounts(creditor, assetKey, assetAmount, underlyingAssetKeys);
    }

    function calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    ) public view returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) {
        (valueInUsd, collateralFactor, liquidationFactor) =
            _calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }

    function getRateUnderlyingAssetsToUsd(address creditor, bytes32[] memory underlyingAssetKeys)
        public
        view
        returns (AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);
    }
}
