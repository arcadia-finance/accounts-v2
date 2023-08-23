/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_IntegrationAndUnit_Test, Constants } from "../Base_IntegrationAndUnit.t.sol";
import { IPricingModule_UsdOnly } from "../../interfaces/IPricingModule_UsdOnly.sol";
import { RiskModule } from "../../RiskModule.sol";
import { CompareArrays } from "../utils/CompareArrays.sol";

contract MainRegistry_Integration_Test is Base_IntegrationAndUnit_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Base_IntegrationAndUnit_Test) {
        Base_IntegrationAndUnit_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

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

    function testRevert_getListOfValuesPerAsset_UnknownBaseCurrency(uint256 basecurrency) public {
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

        uint256 stable1ValueInUsd = (Constants.WAD * rates.stable1ToUsd * assetAmounts[0])
            / 10 ** (Constants.stableOracleDecimals + Constants.stableDecimals);
        uint256 token1ValueInUsd = (Constants.WAD * rates.token1ToUsd * assetAmounts[1])
            / 10 ** (Constants.tokenOracleDecimals + Constants.tokenDecimals);
        uint256 nft1ValueInUsd = Constants.WAD
            * (
                (rates.nft1ToToken1 * assetAmounts[2] * rates.token1ToUsd)
                    / 10 ** (Constants.nftOracleDecimals + Constants.tokenOracleDecimals)
            );

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

    function test_getListOfValuesPerAsset_BaseCurrencyIsId1() public {
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

        uint256 stable1ValueInUsd = (Constants.WAD * rates.stable1ToUsd * assetAmounts[0])
            / 10 ** (Constants.stableOracleDecimals + Constants.stableDecimals);
        uint256 token1ValueInUsd = (Constants.WAD * rates.token1ToUsd * assetAmounts[1])
            / 10 ** (Constants.tokenOracleDecimals + Constants.tokenDecimals);
        uint256 nft1ValueInUsd = Constants.WAD
            * (
                (rates.nft1ToToken1 * assetAmounts[2] * rates.token1ToUsd)
                    / 10 ** (Constants.nftOracleDecimals + Constants.tokenOracleDecimals)
            );

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
}
