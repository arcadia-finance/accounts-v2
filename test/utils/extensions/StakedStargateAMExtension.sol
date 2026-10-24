/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";
import { StakedStargateAM } from "../../../src/asset-modules/Stargate-Finance/StakedStargateAM.sol";

contract StakedStargateAMExtension is StakedStargateAM {
    constructor(address owner_, address registry, address stargateLpStaking_, address surplusRecipient_)
        StakedStargateAM(owner_, registry, stargateLpStaking_, surplusRecipient_)
    { }

    function setAssetToPoolId(address asset, uint256 pid) public {
        assetToPid[asset] = pid;
    }

    function getCurrentReward(address asset) public view returns (uint256 currentReward) {
        currentReward = _getCurrentReward(0, asset);
    }

    function stake(address asset, uint256 amount) public {
        _stakeAndClaim(0, asset, amount);
    }

    function withdraw(address asset, uint256 amount) public {
        _withdrawAndClaim(0, asset, amount);
    }

    function claimReward(address asset) public {
        _claimReward(0, asset);
    }

    function calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    ) public view returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) {
        (valueInUsd, collateralFactor, liquidationFactor) =
            _calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }

    function isInitialized() public view returns (bool) {
        return initialized;
    }
}
