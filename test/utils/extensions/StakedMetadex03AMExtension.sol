/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";
import { StakedMetadex03AM } from "../../../src/asset-modules/Metadex03/StakedMetadex03AM.sol";

contract StakedMetadex03AMExtension is StakedMetadex03AM {
    constructor(
        address owner_,
        address registry,
        address stableGaugeFactory,
        address volatileGaugeFactory,
        address surplusRecipient_
    ) StakedMetadex03AM(owner_, registry, stableGaugeFactory, volatileGaugeFactory, surplusRecipient_) { }

    function stakeAndClaim(uint256 positionId, address asset, uint256 amount) public {
        bookedSurplus += _stakeAndClaim(positionId, asset, amount);
        lastRewardBalance = REWARD_TOKEN.balanceOf(address(this));
    }

    function withdrawAndClaim(uint256 positionId, address asset, uint256 amount) public {
        bookedSurplus += _withdrawAndClaim(positionId, asset, amount);
        lastRewardBalance = REWARD_TOKEN.balanceOf(address(this));
    }

    function claimReward(uint256 positionId, address asset) public {
        bookedSurplus += _claimReward(positionId, asset);
        lastRewardBalance = REWARD_TOKEN.balanceOf(address(this));
    }

    function getLastRewardBalance() public view returns (uint256 lastRewardBalance_) {
        lastRewardBalance_ = lastRewardBalance;
    }

    function setLastRewardBalance(uint256 lastRewardBalance_) public {
        lastRewardBalance = lastRewardBalance_;
    }

    function setBookedSurplus(uint256 bookedSurplus_) public {
        bookedSurplus = bookedSurplus_;
    }

    function mintIdTo(address to, uint256 tokenId) public {
        _safeMint(to, tokenId);
    }

    function getCurrentReward(uint256 positionId, address asset) public view returns (uint256 currentReward) {
        currentReward = _getCurrentReward(positionId, asset);
    }

    function getLastPositionId() public view returns (uint256 lastPositionId_) {
        lastPositionId_ = lastPositionId;
    }

    function setLastPositionId(uint256 lastPositionId_) public {
        lastPositionId = lastPositionId_;
    }

    function setAllowed(address asset, bool allowed) public {
        assetState[asset].allowed = allowed;
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
        // forge-lint: disable-next-line(unsafe-typecast)
        positionState[id].amountStaked = uint128(amount);
    }

    function setTotalStakedForAsset(address asset, uint128 totalStaked_) public {
        assetState[asset].totalStaked = totalStaked_;
    }

    function getKeyFromAsset(address asset, uint256 assetId) public view returns (bytes32 key) {
        key = _getKeyFromAsset(asset, assetId);
    }

    function setOwnerOfPositionId(address owner_, uint256 positionId) public {
        _ownerOf[positionId] = owner_;
    }

    function calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    ) public view returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) {
        (valueInUsd, collateralFactor, liquidationFactor) =
            _calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }

    function getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256 amount,
        bytes32[] memory underlyingAssetKeys
    )
        public
        view
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) =
            _getUnderlyingAssetsAmounts(creditor, assetKey, amount, underlyingAssetKeys);
    }

    function getUnderlyingAssets(bytes32 assetKey) public view returns (bytes32[] memory underlyingAssetKeys) {
        underlyingAssetKeys = _getUnderlyingAssets(assetKey);
    }

    function getRateUnderlyingAssetsToUsd(address creditor, bytes32[] memory underlyingAssetKeys)
        public
        view
        returns (AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);
    }
}
