/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractWrappedAM_Fuzz_Test, WrappedAM } from "./_AbstractWrappedAM.fuzz.t.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { Utils } from "../../../utils/Utils.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "getRiskFactors" of contract "WrappedAM".
 */
contract GetRiskFactors_WrappedAM_Fuzz_Test is AbstractWrappedAM_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractWrappedAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Success_getRiskFactors(
        uint256[2] memory assetRates,
        uint16[2] memory collateralFactors,
        uint16[2] memory liquidationFactors,
        uint16 riskFactor,
        address creditor,
        uint256[2] memory underlyingAssetsAmounts
    ) public {
        // Given amounts do not overflow.
        underlyingAssetsAmounts[0] = bound(underlyingAssetsAmounts[0], 0 forge, type(uint64).max);
        underlyingAssetsAmounts[1] = bound(underlyingAssetsAmounts[1], 0, type(uint64).max);
        assetRates[0] = bound(assetRates[0], 0, type(uint64).max);
        assetRates[1] = bound(assetRates[1], 0, type(uint64).max);

        uint256 value0 = underlyingAssetsAmounts[0].mulDivDown(assetRates[0], 1e18);
        uint256 value1 = underlyingAssetsAmounts[1].mulDivDown(assetRates[1], 1e18);
        uint256 expectedValueInUsd = value0 + value1;
        vm.assume(expectedValueInUsd > 0);

        // And: Risk factors are below max risk factor.
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        collateralFactors[0] = uint16(bound(collateralFactors[0], 0, AssetValuationLib.ONE_4));
        collateralFactors[1] = uint16(bound(collateralFactors[1], 0, AssetValuationLib.ONE_4));
        liquidationFactors[0] = uint16(bound(liquidationFactors[0], collateralFactors[0], AssetValuationLib.ONE_4));
        liquidationFactors[1] = uint16(bound(liquidationFactors[1], collateralFactors[1], AssetValuationLib.ONE_4));

        // And riskFactor is set.
        vm.startPrank(address(registryExtension));
        wrappedAM.setRiskParameters(creditor, 0, riskFactor);
        erc20AssetModule.setRiskParameters(
            creditor, address(mockERC20.token1), 0, 0, collateralFactors[0], liquidationFactors[0]
        );
        erc20AssetModule.setRiskParameters(
            creditor, address(mockERC20.stable1), 0, 0, collateralFactors[1], liquidationFactors[1]
        );
        vm.stopPrank();

        // And: An asset is added
        address asset = address(mockERC20.token1);
        address[] memory rewards = new address[](1);
        rewards[0] = address(mockERC20.stable1);
        vm.prank(users.creatorAddress);
        wrappedAM.setMaxRewardsPerAsset(1);
        address customAsset = getCustomAsset(asset, rewards);
        wrappedAM.addAsset(customAsset, asset, rewards);
        wrappedAM.setCustomAssetForPosition(customAsset, 1);
        wrappedAM.setAmountWrappedForPosition(1, underlyingAssetsAmounts[0]);
        wrappedAM.setTotalWrapped(asset, uint128(underlyingAssetsAmounts[0]));
        wrappedAM.setLastRewardPosition(1, rewards[0], uint128(underlyingAssetsAmounts[1]));

        // And : For the example we say asset is equal to underlying asset
        wrappedAM.setAssetToUnderlyingAsset(asset, asset);

        uint256 expectedCollateralFactor = (
            (value0 * collateralFactors[0] + value1 * collateralFactors[1]) / expectedValueInUsd
        ) * (riskFactor / AssetValuationLib.ONE_4);
        uint256 expectedLiquidationFactor = (
            (value0 * liquidationFactors[0] + value1 * liquidationFactors[1]) / expectedValueInUsd
        ) * (riskFactor / AssetValuationLib.ONE_4);

        // When : calling getRiskFactors()
        // Then : It should return correct values
        (uint256 collateralFactor, uint256 liquidationFactor) = wrappedAM.getRiskFactors(creditor, customAsset, 1);
        assertApproxEqRel(expectedCollateralFactor, collateralFactor, 1e15); //0.1% tolerance, rounding errors
        assertApproxEqRel(expectedLiquidationFactor, liquidationFactor, 1e15); //0.1% tolerance, rounding errors
    }
}
