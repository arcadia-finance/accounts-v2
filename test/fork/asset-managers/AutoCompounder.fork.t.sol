/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fork_Test } from "../Fork.t.sol";
//import { AutoCompounder } from "../../../../src/asset-managers/AutoCompounder.sol";
import { INonfungiblePositionManager } from "../../../../src/asset-managers/interfaces/INonfungiblePositionManager.sol";
import { IUniswapV3Factory } from "../../../../src/asset-managers/interfaces/IUniswapV3Factory.sol";
import { IUniswapV3Pool } from "../../../../src/asset-managers/interfaces/IUniswapV3Pool.sol";
import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { IRegistry } from "../../../../src/asset-managers/interfaces/IRegistry.sol";

/**
 * @notice Common logic needed by all "AutoCompounder" fork tests.
 */
contract AutoCompounder_Fork_Test is Fork_Test {
    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    //AutoCompounder internal autoCompounder;

    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    IUniswapV3Factory public constant UNI_V3_FACTORY = IUniswapV3Factory(0x33128a8fC17869897dcE68Ed026d694621f6FDfD);
    IRegistry public constant REGISTRY = IRegistry(0xd0690557600eb8Be8391D1d97346e2aab5300d5f);
    INonfungiblePositionManager public constant NONFUNGIBLE_POSITIONMANAGER =
        INonfungiblePositionManager(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Fork_Test.setUp();

        //vm.prank(users.creatorAddress);
        //autoCompounder = new AutoCompounder(REGISTRY, UNI_V3_FACTORY);
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFork_Success_ratio() public {
        (,, address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper,,,,,) =
            NONFUNGIBLE_POSITIONMANAGER.positions(421_562);

        address pool = UNI_V3_FACTORY.getPool(token0, token1, fee);
        (uint160 sqrtPriceX96, int24 currentTick,,,,,) = IUniswapV3Pool(pool).slot0();

        emit log_named_int("currentTick", currentTick);
        emit log_named_int("tickUpper", tickUpper);
        emit log_named_int("tickLower", tickLower);
        uint256 ticksInRange = uint256(int256(-tickLower + tickUpper));
        emit log_named_uint("ticksInRange", ticksInRange);
        uint256 ticksFromCurrentToUpperTick = uint256(int256(-currentTick + tickUpper));
        emit log_named_uint("ticksFromCurrentToUpperTick", ticksFromCurrentToUpperTick);

        uint256 token0Ratio = ticksFromCurrentToUpperTick * type(uint24).max / (ticksInRange + 1);
        emit log_named_uint("token0Ratio", token0Ratio);

        uint256 totalFeeValue = 2e18;
        uint256 totalFee0Value = 1e18 + 5e17;
        uint256 feeAmount0 = 2e18;
        uint256 targetToken0Value = token0Ratio * totalFeeValue / type(uint24).max;
        emit log_named_uint("targetToken0Value", targetToken0Value);

        uint256 excessRatioToken0 = ((totalFee0Value - targetToken0Value) * 1e18) / totalFee0Value;
        emit log_named_uint("excessRatioToken0", excessRatioToken0);

        uint256 amount0ToSwap = excessRatioToken0 * feeAmount0 / 1e18;
        emit log_named_uint("amount0ToSwap", amount0ToSwap);
    }

    function testFork_Success_prices() public {
        (,, address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper,,,,,) =
            NONFUNGIBLE_POSITIONMANAGER.positions(421_562);

        address[] memory assets = new address[](2);
        assets[0] = token0;
        assets[1] = token1;
        uint256[] memory assetIds = new uint256[](2);
        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 1e6;
        assetAmounts[1] = 1e6;

        AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            REGISTRY.getValuesInUsd(address(0), assets, assetIds, assetAmounts);

        emit log_named_uint("priceToken0", valuesAndRiskFactors[0].assetValue);
        emit log_named_uint("priceToken1", valuesAndRiskFactors[1].assetValue);
    }
}
