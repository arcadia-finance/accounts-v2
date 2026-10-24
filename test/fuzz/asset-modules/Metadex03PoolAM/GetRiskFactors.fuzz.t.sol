/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValuationLib } from "../../../../src/libraries/AssetValuationLib.sol";
import { FixedPointMathLib } from "../../../../src/asset-modules/abstracts/AbstractDerivedAM.sol";
import { Metadex03PoolAM_Fuzz_Test } from "./_Metadex03PoolAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "getRiskFactors" of contract "Metadex03PoolAM".
 */
contract GetRiskFactors_Metadex03PoolAM_Fuzz_Test is Metadex03PoolAM_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Metadex03PoolAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getRiskFactors(
        bool stable,
        uint16 riskFactor,
        uint16 collateralFactor0,
        uint16 collateralFactor1,
        uint16 liquidationFactor0,
        uint16 liquidationFactor1,
        address creditor,
        uint256 assetId
    ) public {
        // Given: The protocol wide risk factor is set.
        // forge-lint: disable-next-item(unsafe-typecast)
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        vm.prank(address(registry));
        metadex03PoolAM.setRiskParameters(creditor, 0, riskFactor);

        // And: A pool of the fuzzed type is added.
        if (stable) metadex03Pool = createPoolMetadex03(address(mockERC20.token1), address(mockERC20.stable1), true);
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(metadex03Pool));

        // And: Both underlying assets have valid risk factors.
        // forge-lint: disable-next-item(unsafe-typecast)
        collateralFactor0 = uint16(bound(collateralFactor0, 0, AssetValuationLib.ONE_4));
        // forge-lint: disable-next-item(unsafe-typecast)
        collateralFactor1 = uint16(bound(collateralFactor1, 0, AssetValuationLib.ONE_4));
        // forge-lint: disable-next-item(unsafe-typecast)
        liquidationFactor0 = uint16(bound(liquidationFactor0, collateralFactor0, AssetValuationLib.ONE_4));
        // forge-lint: disable-next-item(unsafe-typecast)
        liquidationFactor1 = uint16(bound(liquidationFactor1, collateralFactor1, AssetValuationLib.ONE_4));
        vm.startPrank(address(registry));
        erc20AM.setRiskParameters(creditor, address(mockERC20.token1), 0, 0, collateralFactor0, liquidationFactor0);
        erc20AM.setRiskParameters(creditor, address(mockERC20.stable1), 0, 0, collateralFactor1, liquidationFactor1);
        vm.stopPrank();

        // When: The risk factors of the pool are queried.
        (uint256 collateralFactor_, uint256 liquidationFactor_) =
            metadex03PoolAM.getRiskFactors(creditor, address(metadex03Pool), assetId);

        // Then: The lowest factor of both underlying assets is returned, lowered with the protocol wide risk factor.
        assertEq(
            collateralFactor_,
            uint256(riskFactor)
                .mulDivDown(
                    collateralFactor0 < collateralFactor1 ? collateralFactor0 : collateralFactor1,
                    AssetValuationLib.ONE_4
                )
        );
        assertEq(
            liquidationFactor_,
            uint256(riskFactor)
                .mulDivDown(
                    liquidationFactor0 < liquidationFactor1 ? liquidationFactor0 : liquidationFactor1,
                    AssetValuationLib.ONE_4
                )
        );
    }
}
