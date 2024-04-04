/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { IEStakedAerodromeAM_Fuzz_Test, StakingAM } from "./_IEStakedAerodromeAM.fuzz.t.sol";

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { FixedPointMathLib } from "../../../../src/asset-modules/abstracts/AbstractStakingAM.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Fuzz tests for the function "getRiskFactors" of contract "IEStakedAerodromeAM".
 */
contract GetRiskFactors_StakedAerodromeAM_Fuzz_Test is IEStakedAerodromeAM_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        IEStakedAerodromeAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getRiskFactors(
        uint16 riskFactor,
        address creditor,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        uint96 positionId
    ) public {
        // Given : Asset is added to stakedAerodromeAM
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);
        deployAerodromeGaugeFixture(address(pool), AERO);
        stakedAerodromeAM.addAsset(address(gauge));

        // And : pool has funds (random amount, has no impact)
        mockERC20.token1.mint(address(pool), 1000 * 1e18);
        mockERC20.stable1.mint(address(pool), 1000 * 1e6);

        vm.prank(users.liquidityProvider);
        pool.mint(users.liquidityProvider);

        // And : Valid state
        (assetState, positionState) = givenValidStakingAMState(assetState, positionState);
        // And: State is persisted.
        setStakedAerodromeAMState(assetState, positionState, address(pool), positionId);

        // And : riskParams are set for stakedAerodromeAM
        vm.prank(address(registryExtension));
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        stakedAerodromeAM.setRiskParameters(creditor, 0, riskFactor);

        bytes32[] memory underlyingAssetKeys = new bytes32[](1);
        underlyingAssetKeys[0] = stakedAerodromeAM.getKeyFromAsset(address(pool), positionId);

        // And : getRateUnderlyingAssetsToUsd is previously tested
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd =
            stakedAerodromeAM.getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);

        // And : Risk factors are below max risk factor.
        uint256 expectedCollateralFactor =
            uint256(riskFactor).mulDivDown(rateUnderlyingAssetsToUsd[0].collateralFactor, 1e4);
        uint256 expectedLiquidationFactor =
            uint256(riskFactor).mulDivDown(rateUnderlyingAssetsToUsd[0].liquidationFactor, 1e4);

        (uint256 collateralFactor, uint256 liquidationFactor) =
            stakedAerodromeAM.getRiskFactors(creditor, address(stakedAerodromeAM), positionId);

        assertEq(collateralFactor, expectedCollateralFactor);
        assertEq(liquidationFactor, expectedLiquidationFactor);
    }
}
