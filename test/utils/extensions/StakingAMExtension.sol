/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";
import { StakingAM } from "../../../src/asset-modules/abstracts/AbstractStakingAM.sol";

abstract contract StakingAMExtension is StakingAM {
    constructor(address registry, string memory name_, string memory symbol_) StakingAM(registry, name_, symbol_) { }

    function addAsset(address asset) public {
        _addAsset(asset);
    }

    function setAssetInPosition(address asset, uint96 tokenId) public {
        positionState[tokenId].asset = asset;
    }

    function setTotalStaked(address asset, uint128 totalStaked_) public {
        assetState[asset].totalStaked = totalStaked_;
    }

    function setLastRewardPerTokenGlobal(address asset, uint128 amount) public {
        assetState[asset].lastRewardPerTokenGlobal = amount;
    }

    function setLastRewardPosition(uint256 id, uint128 rewards_) public {
        positionState[id].lastRewardPosition = rewards_;
    }

    function setLastRewardPerTokenPosition(uint256 id, uint128 rewardPaid) public {
        positionState[id].lastRewardPerTokenPosition = rewardPaid;
    }

    function setAmountStakedForPosition(uint256 id, uint256 amount) public {
        positionState[id].amountStaked = uint128(amount);
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

    function getRewardBalances(AssetState memory assetState_, PositionState memory positionState_)
        public
        view
        returns (AssetState memory, PositionState memory)
    {
        return _getRewardBalances(assetState_, positionState_);
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

    function setTotalStakedForAsset(address asset, uint128 totalStaked_) public {
        assetState[asset].totalStaked = totalStaked_;
    }

    function calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    ) public view returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) {
        (valueInUsd, collateralFactor, liquidationFactor) =
            _calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }
}
