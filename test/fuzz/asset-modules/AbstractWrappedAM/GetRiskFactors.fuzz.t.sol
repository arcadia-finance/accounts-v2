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
        uint16[2] memory collateralFactors,
        uint16[2] memory liquidationFactors,
        uint16 riskFactor,
        address creditor,
        uint256[2] memory underlyingAssetsAmounts
    ) public {
        // Given : wrappedAM is an Asset Module and is initialized
        vm.startPrank(users.creatorAddress);
        registryExtension.addAssetModule(address(wrappedAM));
        wrappedAM.initialize(1);
        vm.stopPrank();

        // ToDo assetRates are hard coded for now.
        uint256[] memory assetRates = new uint256[](2);
        assetRates[0] = 3_000_000_000_000_000_000_000;
        assetRates[1] = 1_000_000_000_000_000_000_000_000_000_000;

        // And : amounts do not overflow.
        underlyingAssetsAmounts[0] = bound(underlyingAssetsAmounts[0], 10_000, type(uint64).max);
        underlyingAssetsAmounts[1] = bound(underlyingAssetsAmounts[1], 10_000, type(uint64).max);

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

        // Given: An asset is added
        address asset = address(mockERC20.token1);
        address[] memory rewards = new address[](1);
        rewards[0] = address(mockERC20.stable1);
        address customAsset = getCustomAsset(asset, rewards);
        wrappedAM.addAsset(customAsset, asset, rewards);
        wrappedAM.setCustomAssetForPosition(customAsset, 1);
        wrappedAM.setAmountWrappedForPosition(1, underlyingAssetsAmounts[0]);
        wrappedAM.setTotalWrapped(asset, uint128(underlyingAssetsAmounts[0]));
        wrappedAM.setLastRewardPosition(1, rewards[0], uint128(underlyingAssetsAmounts[1]));
        // And : Asset and underlying asset are the same
        wrappedAM.setAssetToUnderlyingAsset(asset, asset);

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

        bytes32 assetKey = wrappedAM.getKeyFromAsset(address(wrappedAM), 1);

        // getUnderlyingAssets() fully tested
        bytes32[] memory underlyingAssetKeys = wrappedAM.getUnderlyingAssets(assetKey);

        // getRateUnderlyingAssetsToUsd() fully tested
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd =
            wrappedAM.getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);

        // calculateValueAndRiskFactors() fully tested
        (, uint256 expectedCollateralFactor, uint256 expectedLiquidationFactor) = wrappedAM.calculateValueAndRiskFactors(
            creditor, Utils.castArrayStaticToDynamic(underlyingAssetsAmounts), rateUnderlyingAssetsToUsd
        );

        // When : calling getRiskFactors
        (uint16 collateralFactor, uint16 liquidationFactor) = wrappedAM.getRiskFactors(creditor, asset, 1);

        // Then : It should return the correct values
        assertEq(expectedCollateralFactor, collateralFactor);
        assertEq(expectedLiquidationFactor, liquidationFactor);
    }
}
