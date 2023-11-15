/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Registry_Fuzz_Test } from "./_Registry.fuzz.t.sol";

import { stdError } from "../../../lib/forge-std/src/StdError.sol";

import { CompareArrays } from "../../utils/CompareArrays.sol";
import { Constants } from "../../utils/Constants.sol";
import { RiskModule } from "../../../src/RiskModule.sol";

/**
 * @notice Fuzz tests for the function "getValuesInBaseCurrency" of contract "Registry".
 */
contract GetListOfValuesPerAsset_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getValuesInBaseCurrency_UnknownAsset() public {
        // Should revert here as mockERC20.token3 was not added to an asset  module
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC20.token3);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert(bytes(""));
        registryExtension.getValuesInBaseCurrency(
            address(0), address(creditorUsd), assetAddresses, assetIds, assetAmounts
        );
    }

    function testFuzz_Revert_getValuesInBaseCurrency_UnknownBaseCurrencyAddress(address baseCurrency) public {
        vm.assume(baseCurrency != address(0));
        vm.assume(!registryExtension.inRegistry(baseCurrency));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.stable2);
        assetAddresses[1] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert(bytes(""));
        registryExtension.getValuesInBaseCurrency(
            baseCurrency, address(creditorUsd), assetAddresses, assetIds, assetAmounts
        );
    }

    function testFuzz_Success_getValuesInBaseCurrency_BaseCurrencyIsUsd() public {
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(mockERC20.stable1);
        assetAddresses[1] = address(mockERC20.token1);
        assetAddresses[2] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 1;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = 10 ** Constants.stableDecimals;
        assetAmounts[1] = 10 ** Constants.tokenDecimals;
        assetAmounts[2] = 1;

        RiskModule.AssetValueAndRiskFactors[] memory actualValuesPerAsset = registryExtension.getValuesInBaseCurrency(
            address(0), address(creditorUsd), assetAddresses, assetIds, assetAmounts
        );

        uint256 stable1ValueInUsd = convertAssetToUsd(Constants.stableDecimals, assetAmounts[0], oracleStable1ToUsdArr);
        uint256 token1ValueInUsd = convertAssetToUsd(Constants.tokenDecimals, assetAmounts[1], oracleToken1ToUsdArr);
        uint256 nft1ValueInUsd = convertAssetToUsd(0, assetAmounts[2], oracleNft1ToToken1ToUsd);

        uint256[] memory expectedListOfValuesPerAsset = new uint256[](3);
        expectedListOfValuesPerAsset[0] = stable1ValueInUsd;
        expectedListOfValuesPerAsset[1] = token1ValueInUsd;
        expectedListOfValuesPerAsset[2] = nft1ValueInUsd;

        uint256[] memory actualListOfValuesPerAsset = new uint256[](3);
        for (uint256 i; i < actualValuesPerAsset.length; ++i) {
            actualListOfValuesPerAsset[i] = actualValuesPerAsset[i].assetValue;
        }

        assertTrue(CompareArrays.compareArrays(expectedListOfValuesPerAsset, actualListOfValuesPerAsset));
    }

    function testFuzz_Success_getValuesInBaseCurrency_BaseCurrencyIsNotUsd() public {
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(mockERC20.stable1);
        assetAddresses[1] = address(mockERC20.token1);
        assetAddresses[2] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 1;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = 10 ** Constants.stableDecimals;
        assetAmounts[1] = 10 ** Constants.tokenDecimals;
        assetAmounts[2] = 1;

        RiskModule.AssetValueAndRiskFactors[] memory actualValuesPerAsset = registryExtension.getValuesInBaseCurrency(
            address(mockERC20.token1), address(creditorUsd), assetAddresses, assetIds, assetAmounts
        );

        uint256 stable1ValueInUsd = convertAssetToUsd(Constants.stableDecimals, assetAmounts[0], oracleStable1ToUsdArr);
        uint256 token1ValueInUsd = convertAssetToUsd(Constants.tokenDecimals, assetAmounts[1], oracleToken1ToUsdArr);
        uint256 nft1ValueInUsd = convertAssetToUsd(0, assetAmounts[2], oracleNft1ToToken1ToUsd);

        uint256 stable1ValueInBCurrency = convertUsdToBaseCurrency(
            Constants.tokenDecimals, stable1ValueInUsd, rates.token1ToUsd, Constants.tokenOracleDecimals
        );
        uint256 token1ValueInBCurrency = convertUsdToBaseCurrency(
            Constants.tokenDecimals, token1ValueInUsd, rates.token1ToUsd, Constants.tokenOracleDecimals
        );
        uint256 nft1ValueInBCurrency = convertUsdToBaseCurrency(
            Constants.tokenDecimals, nft1ValueInUsd, rates.token1ToUsd, Constants.tokenOracleDecimals
        );

        uint256[] memory expectedListOfValuesPerAsset = new uint256[](3);
        expectedListOfValuesPerAsset[0] = stable1ValueInBCurrency;
        expectedListOfValuesPerAsset[1] = token1ValueInBCurrency;
        expectedListOfValuesPerAsset[2] = nft1ValueInBCurrency;

        uint256[] memory actualListOfValuesPerAsset = new uint256[](3);
        for (uint256 i; i < actualValuesPerAsset.length; ++i) {
            actualListOfValuesPerAsset[i] = actualValuesPerAsset[i].assetValue;
        }

        assertTrue(CompareArrays.compareArrays(expectedListOfValuesPerAsset, actualListOfValuesPerAsset));
    }
}
