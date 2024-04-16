/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";
import { StakedStargateAM } from "../../../src/asset-modules/Stargate-Finance/StakedStargateAM.sol";

contract StakedStargateAMExtension is StakedStargateAM {
    constructor(address registry, address stargateLpStaking_) StakedStargateAM(registry, stargateLpStaking_) { }

    function setAssetToPoolId(address asset, uint256 pid) public {
        assetToPid[asset] = pid;
    }

    function getCurrentReward(address asset) public view returns (uint256 currentReward) {
        currentReward = _getCurrentReward(asset);
    }

    function stake(address asset, uint256 amount) public {
        _stakeAndClaim(asset, amount);
    }

    function withdraw(address asset, uint256 amount) public {
        _withdrawAndClaim(asset, amount);
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
