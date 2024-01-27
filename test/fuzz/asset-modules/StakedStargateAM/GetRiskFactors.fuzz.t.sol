/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StakedStargateAM_Fuzz_Test } from "./_StakedStargateAM.fuzz.t.sol";

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Fuzz tests for the function "getRiskFactors" of contract "StakedStargateAM".
 */
contract GetRiskFactors_StakedStargateAM_Fuzz_Test is StakedStargateAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedStargateAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getRiskFactors_NonZeroValueInUsd(
        uint256[2] memory assetRates,
        uint16[2] memory collateralFactors,
        uint16[2] memory liquidationFactors,
        uint16 riskFactor,
        address creditor,
        uint256[2] memory underlyingAssetsAmounts,
        uint256 poolId,
        uint256 pid
    ) public {
        // ToDo assetRates are hard coded for now.
        assetRates[0] = 3_000_000_000_000_000_000_000;
        assetRates[1] = 6_000_000_000_000_000_000_000;

        // Given amounts do not overflow.
        underlyingAssetsAmounts[0] = bound(underlyingAssetsAmounts[0], 10_000, type(uint64).max);
        underlyingAssetsAmounts[1] = bound(underlyingAssetsAmounts[1], 10_000, type(uint64).max);

        uint256 value0 = underlyingAssetsAmounts[0] * assetRates[0] / 1e18;
        uint256 value1 = underlyingAssetsAmounts[1] * assetRates[1] / 1e18;
        uint256 expectedValueInUsd = value0 + value1;
        vm.assume(expectedValueInUsd > 0);

        // And: Risk factors are below max risk factor.
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        collateralFactors[0] = uint16(bound(collateralFactors[0], 0, AssetValuationLib.ONE_4));
        collateralFactors[1] = uint16(bound(collateralFactors[1], 0, AssetValuationLib.ONE_4));
        liquidationFactors[0] = uint16(bound(liquidationFactors[0], collateralFactors[0], AssetValuationLib.ONE_4));
        liquidationFactors[1] = uint16(bound(liquidationFactors[1], collateralFactors[1], AssetValuationLib.ONE_4));

        // And riskFactor is set.
        vm.prank(address(registryExtension));
        stakedStargateAM.setRiskParameters(creditor, 0, riskFactor);

        // And state stargateAssetModule is set.
        sgFactoryMock.setPool(poolId, address(poolMock));
        poolMock.setToken(address(mockERC20.token1));
        stargateAssetModule.addAsset(poolId);
        vm.startPrank(address(registryExtension));
        stargateAssetModule.setRiskParameters(creditor, 0, uint16(AssetValuationLib.ONE_4));
        erc20AssetModule.setRiskParameters(
            creditor, address(mockERC20.token1), 0, 0, collateralFactors[0], liquidationFactors[0]
        );
        vm.stopPrank();

        // And staked pool is set.
        lpStakingTimeMock.setInfoForPoolId(pid, 0, address(poolMock));
        stakedStargateAM.addAsset(pid);
        vm.startPrank(address(registryExtension));
        erc20AssetModule.setRiskParameters(
            creditor, address(lpStakingTimeMock.eToken()), 0, 0, collateralFactors[1], liquidationFactors[1]
        );
        vm.stopPrank();

        // And position is minted.
        poolMock.setState(address(mockERC20.token1), underlyingAssetsAmounts[0], underlyingAssetsAmounts[0], 1);
        deal(address(poolMock), users.liquidityProvider, underlyingAssetsAmounts[0], true);
        vm.startPrank(users.liquidityProvider);
        poolMock.approve(address(stakedStargateAM), underlyingAssetsAmounts[0]);
        uint256 positionId = stakedStargateAM.mint(address(poolMock), uint128(underlyingAssetsAmounts[0]));
        vm.stopPrank();

        // And reward is available.
        lpStakingTimeMock.setInfoForPoolId(pid, underlyingAssetsAmounts[1], address(poolMock));

        uint256 expectedCollateralFactor = riskFactor
            * ((value0 * collateralFactors[0] + value1 * collateralFactors[1]) / expectedValueInUsd)
            / AssetValuationLib.ONE_4;
        uint256 expectedLiquidationFactor = riskFactor
            * ((value0 * liquidationFactors[0] + value1 * liquidationFactors[1]) / expectedValueInUsd)
            / AssetValuationLib.ONE_4;

        (uint256 collateralFactor, uint256 liquidationFactor) =
            stakedStargateAM.getRiskFactors(creditor, address(stakedStargateAM), positionId);
        assertApproxEqAbs(collateralFactor, expectedCollateralFactor, 10); //0.1% tolerance, rounding errors
        assertApproxEqAbs(liquidationFactor, expectedLiquidationFactor, 10); //0.1% tolerance, rounding errors
    }

    function testFuzz_Success_getRiskFactors_ZeroValueInUsd(
        uint16[2] memory collateralFactors,
        uint16[2] memory liquidationFactors,
        uint16 riskFactor,
        address creditor,
        uint256[2] memory underlyingAssetsAmounts,
        uint256 poolId,
        uint256 pid
    ) public {
        // Set rates to 0.
        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(0));
        stargateOracle.transmit(int256(0));
        vm.stopPrank();

        // Given amounts do not overflow.
        underlyingAssetsAmounts[0] = bound(underlyingAssetsAmounts[0], 1, type(uint64).max);
        underlyingAssetsAmounts[1] = bound(underlyingAssetsAmounts[1], 0, type(uint64).max);

        // And: Risk factors are below max risk factor.
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        collateralFactors[0] = uint16(bound(collateralFactors[0], 0, AssetValuationLib.ONE_4));
        collateralFactors[1] = uint16(bound(collateralFactors[1], 0, AssetValuationLib.ONE_4));
        liquidationFactors[0] = uint16(bound(liquidationFactors[0], collateralFactors[0], AssetValuationLib.ONE_4));
        liquidationFactors[1] = uint16(bound(liquidationFactors[1], collateralFactors[1], AssetValuationLib.ONE_4));

        // And riskFactor is set.
        vm.prank(address(registryExtension));
        stakedStargateAM.setRiskParameters(creditor, 0, riskFactor);

        // And state stargateAssetModule is set.
        sgFactoryMock.setPool(poolId, address(poolMock));
        poolMock.setToken(address(mockERC20.token1));
        stargateAssetModule.addAsset(poolId);
        vm.startPrank(address(registryExtension));
        stargateAssetModule.setRiskParameters(creditor, 0, uint16(AssetValuationLib.ONE_4));
        erc20AssetModule.setRiskParameters(
            creditor, address(mockERC20.token1), 0, 0, collateralFactors[0], liquidationFactors[0]
        );
        vm.stopPrank();

        // And staked pool is set.
        lpStakingTimeMock.setInfoForPoolId(pid, 0, address(poolMock));
        stakedStargateAM.addAsset(pid);
        vm.startPrank(address(registryExtension));
        erc20AssetModule.setRiskParameters(
            creditor, address(lpStakingTimeMock.eToken()), 0, 0, collateralFactors[1], liquidationFactors[1]
        );
        vm.stopPrank();

        // And position is minted.
        poolMock.setState(address(mockERC20.token1), underlyingAssetsAmounts[0], underlyingAssetsAmounts[0], 1);
        deal(address(poolMock), users.liquidityProvider, underlyingAssetsAmounts[0], true);
        vm.startPrank(users.liquidityProvider);
        poolMock.approve(address(stakedStargateAM), underlyingAssetsAmounts[0]);
        uint256 positionId = stakedStargateAM.mint(address(poolMock), uint128(underlyingAssetsAmounts[0]));
        vm.stopPrank();

        // And reward is available.
        lpStakingTimeMock.setInfoForPoolId(pid, underlyingAssetsAmounts[1], address(poolMock));

        (uint256 collateralFactor, uint256 liquidationFactor) =
            stakedStargateAM.getRiskFactors(creditor, address(stakedStargateAM), positionId);
        assertEq(collateralFactor, 0);
        assertEq(liquidationFactor, 0);
    }
}
