/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";
import { StakedAerodromeAM } from "../../../src/asset-modules/Aerodrome-Finance/StakedAerodromeAM.sol";

contract StakedAerodromeAMExtension is StakedAerodromeAM {
    constructor(address registry, address aerodromeVoter) StakedAerodromeAM(registry, aerodromeVoter) { }

    function stakeAndClaim(address asset, uint256 amount) public {
        _stakeAndClaim(asset, amount);
    }

    function withdrawAndClaim(address asset, uint256 amount) public {
        _withdrawAndClaim(asset, amount);
    }

    function claimReward(address asset) public {
        _claimReward(asset);
    }

    function mintIdTo(address to, uint256 tokenId) public {
        _safeMint(to, tokenId);
    }

    function getCurrentReward(address asset) public view returns (uint256 currentReward) {
        currentReward = _getCurrentReward(asset);
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
