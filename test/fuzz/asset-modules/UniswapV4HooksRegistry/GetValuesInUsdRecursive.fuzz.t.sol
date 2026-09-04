/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { OracleModuleMock } from "../../../utils/mocks/oracle-modules/OracleModuleMock.sol";
import { PrimaryAMMock } from "../../../utils/mocks/asset-modules/PrimaryAMMock.sol";
import { UniswapV4HooksRegistry_Fuzz_Test } from "./_UniswapV4HooksRegistry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "getValuesInUsdRecursive" of contract "UniswapV4HooksRegistry".
 */
// forge-lint: disable-next-item(mixed-case-variable,unsafe-typecast)
contract GetValuesInUsdRecursive_UniswapV4HooksRegistry_Fuzz_Test is UniswapV4HooksRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    // forge-lint: disable-next-line(mixed-case-variable)
    OracleModuleMock internal oracleModule;
    PrimaryAMMock internal primaryAM;

    uint256 internal constant PRIMARY_AM_ORACLE_ID = 999;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4HooksRegistry_Fuzz_Test.setUp();

        vm.startPrank(users.owner);
        primaryAM = new PrimaryAMMock(users.owner, address(registry), 0);
        oracleModule = new OracleModuleMock(users.owner, address(registry));
        registry.addAssetModule(address(primaryAM));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function addMockedOracle(uint256 oracleId, uint256 rate, bytes16 baseAsset, bytes16 quoteAsset, bool active)
        public
    {
        oracleModule.setOracle(oracleId, baseAsset, quoteAsset, active);
        registry.setOracleToOracleModule(oracleId, address(oracleModule));
        oracleModule.setRate(oracleId, rate);
    }

    // forge-lint: disable-next-item(mixed-case-function,unsafe-typecast)
    function setPrimaryAMOracle(address asset, uint256 assetId, uint64 assetUnit, uint256 usdValue) public {
        addMockedOracle(PRIMARY_AM_ORACLE_ID, usdValue, bytes16("A"), bytes16("USD"), true);
        uint80[] memory oracleIds = new uint80[](1);
        oracleIds[0] = uint80(PRIMARY_AM_ORACLE_ID);
        bool[] memory baseToQuoteAsset = new bool[](1);
        baseToQuoteAsset[0] = true;
        primaryAM.setAssetInformation(asset, assetId, assetUnit, BitPackingLib.pack(baseToQuoteAsset, oracleIds));
    }

    function testFuzz_Revert_getValuesInUsdRecursive_UnknownAsset(
        address creditor,
        address asset,
        uint96 assetId,
        uint256 assetAmount
    ) public {
        vm.assume(asset != address(mockERC20.stable1));
        vm.assume(asset != address(mockERC20.stable2));
        vm.assume(asset != address(mockERC20.token1));
        vm.assume(asset != address(mockERC20.token2));
        vm.assume(asset != address(mockERC721.nft1));
        vm.assume(asset != address(mockERC1155.sft1));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = assetId;
        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = assetAmount;

        vm.expectRevert(bytes(""));
        v4HooksRegistry.getValuesInUsdRecursive(creditor, assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Success_getValuesInUsdRecursive(
        address asset,
        uint96 assetId,
        uint256 assetAmount,
        uint64 assetUnit,
        uint256 usdValue,
        uint128 minUsdValue,
        uint112 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        collateralFactor = uint16(bound(collateralFactor, 0, AssetValuationLib.ONE_4));
        liquidationFactor = uint16(bound(liquidationFactor, collateralFactor, AssetValuationLib.ONE_4));

        registry.setAssetModule(asset, address(primaryAM));

        // And: The asset price does not overflow and its value stays below "minUsdValue".
        assetUnit = uint64(bound(assetUnit, 1, type(uint64).max));
        usdValue = bound(usdValue, 0, type(uint256).max / 1e18);
        assetAmount = bound(
            assetAmount, 0, usdValue == 0 ? type(uint256).max : (type(uint128).max - 1) * uint256(assetUnit) / usdValue
        );
        uint256 assetValue = assetAmount * usdValue / assetUnit;
        minUsdValue = uint128(bound(minUsdValue, assetValue + 1, type(uint128).max));
        setPrimaryAMOracle(asset, assetId, assetUnit, usdValue);

        vm.startPrank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), asset, assetId, maxExposure, collateralFactor, liquidationFactor
        );
        registry.setRiskParameters(address(creditorUsd), minUsdValue, 0, type(uint64).max);
        vm.stopPrank();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = assetId;
        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = assetAmount;

        AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            v4HooksRegistry.getValuesInUsdRecursive(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        assertEq(valuesAndRiskFactors[0].assetValue, assetValue);
        assertEq(valuesAndRiskFactors[0].collateralFactor, collateralFactor);
        assertEq(valuesAndRiskFactors[0].liquidationFactor, liquidationFactor);
    }
}
