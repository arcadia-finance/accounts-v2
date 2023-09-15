/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, MainRegistry_Fuzz_Test } from "./_MainRegistry.fuzz.t.sol";

import { CompareArrays } from "../../utils/CompareArrays.sol";
import { RiskModule } from "../../../RiskModule.sol";

/**
 * @notice Fuzz tests for the "getListOfValuesPerAsset" of contract "MainRegistry".
 */
contract GetListOfValuesPerAsset_MainRegistry_Fuzz_Test is MainRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MainRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_getListOfValuesPerAsset_UnknownAsset() public {
        // Should revert here as mockERC20.token3 was not added to a pricing module
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
        mainRegistryExtension.getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, 0);
    }

    function testRevert_Fuzz_getListOfValuesPerAsset_UnknownBaseCurrencyId(uint256 basecurrency) public {
        // Given: the baseCurrencyID is greater than the number of baseCurrencies added in the protocol
        vm.assume(basecurrency >= 3);

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert(bytes(""));
        mainRegistryExtension.getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, basecurrency);
    }

    function testRevert_Fuzz_getListOfValuesPerAsset_UnknownBaseCurrencyAddress(address basecurrency) public {
        vm.assume(basecurrency != address(0));
        vm.assume(basecurrency != address(mockERC20.stable1));
        vm.assume(basecurrency != address(mockERC20.token1));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.stable2);
        assetAddresses[1] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert("MR_GLVA: UNKNOWN_BASECURRENCY");
        mainRegistryExtension.getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, basecurrency);
    }

    function test_getListOfValuesPerAsset_BaseCurrencyIsUsd() public {
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

        RiskModule.AssetValueAndRiskVariables[] memory actualValuesPerAsset =
            mainRegistryExtension.getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, UsdBaseCurrencyID);

        uint256 stable1ValueInUsd = convertAssetToUsd(Constants.stableDecimals, assetAmounts[0], oracleStable1ToUsdArr);
        uint256 token1ValueInUsd = convertAssetToUsd(Constants.tokenDecimals, assetAmounts[1], oracleToken1ToUsdArr);
        uint256 nft1ValueInUsd = convertAssetToUsd(0, assetAmounts[2], oracleNft1ToToken1ToUsd);

        uint256[] memory expectedListOfValuesPerAsset = new uint256[](3);
        expectedListOfValuesPerAsset[0] = stable1ValueInUsd;
        expectedListOfValuesPerAsset[1] = token1ValueInUsd;
        expectedListOfValuesPerAsset[2] = nft1ValueInUsd;

        uint256[] memory actualListOfValuesPerAsset = new uint256[](3);
        for (uint256 i; i < actualValuesPerAsset.length; ++i) {
            actualListOfValuesPerAsset[i] = actualValuesPerAsset[i].valueInBaseCurrency;
        }

        assertTrue(CompareArrays.compareArrays(expectedListOfValuesPerAsset, actualListOfValuesPerAsset));
    }

    function test_getListOfValuesPerAsset_BaseCurrencyIsNotUsd() public {
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

        RiskModule.AssetValueAndRiskVariables[] memory actualValuesPerAsset =
            mainRegistryExtension.getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, Token1BaseCurrencyID);

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
            actualListOfValuesPerAsset[i] = actualValuesPerAsset[i].valueInBaseCurrency;
        }

        assertTrue(CompareArrays.compareArrays(expectedListOfValuesPerAsset, actualListOfValuesPerAsset));
    }
}
