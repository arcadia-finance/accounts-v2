/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_IntegrationAndUnit_Test, Constants } from "../Base_IntegrationAndUnit.t.sol";
import { IPricingModule_UsdOnly } from "../../interfaces/IPricingModule_UsdOnly.sol";
import { PricingModule_UsdOnly } from "../../PricingModules/AbstractPricingModule_UsdOnly.sol";
import { OracleHub_UsdOnly } from "../../OracleHub_UsdOnly.sol";
import { ArcadiaOracle } from "../../mockups/ArcadiaOracle.sol";
import { RiskModule } from "../../RiskModule.sol";
import { CompareArrays } from "../utils/CompareArrays.sol";
import { RiskConstants } from "../../utils/RiskConstants.sol";
import { ERC20Mock } from "../../mockups/ERC20SolmateMock.sol";

contract MainRegistry_Integration_Test is Base_IntegrationAndUnit_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                         HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function convertAssetToUsd(uint256 assetDecimals, uint256 amount, address[] memory oracleArr)
        public
        view
        returns (uint256 usdValue)
    {
        uint256 ratesMultiplied = 1;
        uint256 sumOfOracleDecimals;
        for (uint8 i; i < oracleArr.length; i++) {
            (, int256 answer,,,) = ArcadiaOracle(oracleArr[i]).latestRoundData();
            ratesMultiplied *= uint256(answer);
            sumOfOracleDecimals += ArcadiaOracle(oracleArr[i]).decimals();
        }

        usdValue = (Constants.WAD * ratesMultiplied * amount) / (10 ** (sumOfOracleDecimals + assetDecimals));
    }

    function convertUsdToBaseCurrency(
        uint256 baseCurrencyDecimals,
        uint256 usdAmount,
        uint256 rateBaseCurrencyToUsd,
        uint256 oracleDecimals
    ) public pure returns (uint256 assetValue) {
        assetValue = (usdAmount * 10 ** oracleDecimals) / rateBaseCurrencyToUsd;
        // USD value will always be in 18 decimals so we have to convert to baseCurrency decimals if needed
        if (baseCurrencyDecimals < 18) {
            assetValue /= 10 ** (18 - baseCurrencyDecimals);
        }
    }

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

    function testRevert_Fuzz_getTotalValue_UnknownBaseCurrency(address basecurrency) public {
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

        vm.expectRevert("MR_GTV: UNKNOWN_BASECURRENCY");
        mainRegistryExtension.getTotalValue(assetAddresses, assetIds, assetAmounts, basecurrency);
    }

    function test_getTotalValue() public {
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC20.token2);
        assetAddresses[2] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 1;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = 10 ** Constants.tokenDecimals;
        assetAmounts[1] = 10 ** Constants.tokenDecimals;
        assetAmounts[2] = 1;

        // BaseCurrency for actualTotalValue is set to mockERC20.token1
        uint256 actualTotalValue =
            mainRegistryExtension.getTotalValue(assetAddresses, assetIds, assetAmounts, address(mockERC20.token1));

        uint256 token1ValueInToken1 = assetAmounts[0];
        uint256 token2ValueInToken1 = convertUsdToBaseCurrency(
            Constants.tokenDecimals,
            convertAssetToUsd(Constants.tokenDecimals, assetAmounts[1], oracleToken2ToUsdArr),
            rates.token1ToUsd,
            Constants.tokenOracleDecimals
        );
        uint256 nft1ValueInToken1 = convertUsdToBaseCurrency(
            Constants.tokenDecimals,
            convertAssetToUsd(0, assetAmounts[2], oracleNft1ToToken1ToUsd),
            rates.token1ToUsd,
            Constants.tokenOracleDecimals
        );

        uint256 expectedTotalValue = token1ValueInToken1 + token2ValueInToken1 + nft1ValueInToken1;

        assertEq(expectedTotalValue, actualTotalValue);
    }

    function testRevert_Fuzz_getCollateralValue_UnknownBaseCurrency(address basecurrency) public {
        vm.assume(basecurrency != address(0));
        vm.assume(basecurrency != address(mockERC20.stable1));
        vm.assume(basecurrency != address(mockERC20.token1));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.stable2);
        assetAddresses[1] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert("MR_GCV: UNKNOWN_BASECURRENCY");
        mainRegistryExtension.getCollateralValue(assetAddresses, assetIds, assetAmounts, basecurrency);
    }

    function testFuzz_getCollateralValue(int64 rateToken1ToUsd, uint64 amountToken1, uint16 collateralFactor_) public {
        vm.assume(collateralFactor_ <= RiskConstants.MAX_COLLATERAL_FACTOR);
        vm.assume(rateToken1ToUsd > 0);

        vm.prank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(rateToken1ToUsd);

        uint256 token1ValueInUsd = convertAssetToUsd(Constants.tokenDecimals, amountToken1, oracleToken1ToUsdArr);
        vm.assume(token1ValueInUsd > 0);

        PricingModule_UsdOnly.RiskVarInput[] memory riskVarsInput = new PricingModule_UsdOnly.RiskVarInput[](1);
        riskVarsInput[0].asset = address(mockERC20.token1);
        riskVarsInput[0].baseCurrency = uint8(UsdBaseCurrencyID);
        riskVarsInput[0].collateralFactor = collateralFactor_;

        vm.startPrank(users.creatorAddress);
        erc20PricingModule.setBatchRiskVariables(riskVarsInput);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken1;

        uint256 actualCollateralValue =
            mainRegistryExtension.getCollateralValue(assetAddresses, assetIds, assetAmounts, address(0));

        uint256 expectedCollateralValue = token1ValueInUsd * collateralFactor_ / 100;

        assertEq(expectedCollateralValue, actualCollateralValue);
    }

    function testRevert_Fuzz_getLiquidationValue_UnknownBaseCurrency(address basecurrency) public {
        vm.assume(basecurrency != address(0));
        vm.assume(basecurrency != address(mockERC20.stable1));
        vm.assume(basecurrency != address(mockERC20.token1));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token2);
        assetAddresses[1] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 1;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 1;

        vm.expectRevert("MR_GLV: UNKNOWN_BASECURRENCY");
        mainRegistryExtension.getLiquidationValue(assetAddresses, assetIds, assetAmounts, basecurrency);
    }

    function test_Fuzz_getLiquidationValue(int64 rateToken1ToUsd, uint64 amountToken1, uint16 liquidationFactor_)
        public
    {
        vm.assume(liquidationFactor_ <= RiskConstants.MAX_LIQUIDATION_FACTOR);
        vm.assume(rateToken1ToUsd > 0);

        vm.prank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(rateToken1ToUsd);

        uint256 token1ValueInUsd = convertAssetToUsd(Constants.tokenDecimals, amountToken1, oracleToken1ToUsdArr);
        vm.assume(token1ValueInUsd > 0);

        PricingModule_UsdOnly.RiskVarInput[] memory riskVarsInput = new PricingModule_UsdOnly.RiskVarInput[](1);
        riskVarsInput[0].asset = address(mockERC20.token1);
        riskVarsInput[0].baseCurrency = uint8(UsdBaseCurrencyID);
        riskVarsInput[0].liquidationFactor = liquidationFactor_;

        vm.startPrank(users.creatorAddress);
        erc20PricingModule.setBatchRiskVariables(riskVarsInput);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken1;

        uint256 actualLiquidationValue =
            mainRegistryExtension.getLiquidationValue(assetAddresses, assetIds, assetAmounts, address(0));

        uint256 expectedLiquidationValue = token1ValueInUsd * liquidationFactor_ / 100;

        assertEq(expectedLiquidationValue, actualLiquidationValue);
    }

    function testFuzz_getTotalValue_CalculateValueInBaseCurrencyFromValueInUsd_token2With18Decimals(
        uint256 rateToken1ToUsd,
        uint256 amountToken2
    ) public {
        vm.assume(rateToken1ToUsd <= uint256(type(int256).max));
        vm.assume(rateToken1ToUsd > 0);

        vm.assume(
            amountToken2
                <= type(uint256).max / uint256(rates.token2ToUsd) / Constants.WAD
                    / 10 ** (Constants.tokenOracleDecimals - Constants.tokenOracleDecimals)
        );
        vm.assume(
            amountToken2
                <= (
                    ((type(uint256).max / uint256(rates.token2ToUsd) / Constants.WAD) * 10 ** Constants.tokenOracleDecimals)
                        / 10 ** Constants.tokenOracleDecimals
                ) * 10 ** Constants.tokenDecimals
        );

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsd));
        vm.stopPrank();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken2;

        uint256 actualTotalValue =
            mainRegistryExtension.getTotalValue(assetAddresses, assetIds, assetAmounts, address(mockERC20.token1));

        uint256 token2ValueInUsd = convertAssetToUsd(Constants.tokenDecimals, amountToken2, oracleToken2ToUsdArr);
        uint256 token2ValueInToken1 = convertUsdToBaseCurrency(
            Constants.tokenDecimals, token2ValueInUsd, rateToken1ToUsd, Constants.tokenOracleDecimals
        );

        uint256 expectedValue = token2ValueInToken1;

        // Then: expectedTotalValue should be equal to actualTotalValue
        assertEq(expectedValue, actualTotalValue);
    }

    function testFuzz_getTotalValue_CalculateValueInBaseCurrencyFromValueInUsd_token2With6decimals(
        uint256 rateToken1ToUsd,
        uint128 amountToken2
    ) public {
        // Here it's safe to consider a max value of uint128.max for amountToken2, as we tested for overflow on previous related test.
        // Objective is to test if calculation hold true with different tokendecimals (in this case mockERC20.stable tokens have 6 decimals)

        vm.assume(rateToken1ToUsd <= uint256(type(int256).max));
        vm.assume(rateToken1ToUsd > 0);

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsd));
        vm.stopPrank();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.stable2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken2;

        uint256 actualTotalValue =
            mainRegistryExtension.getTotalValue(assetAddresses, assetIds, assetAmounts, address(mockERC20.token1));

        uint256 token2ValueInUsd = convertAssetToUsd(Constants.stableDecimals, amountToken2, oracleStable2ToUsdArr);
        uint256 token2ValueInToken1 = convertUsdToBaseCurrency(
            Constants.tokenDecimals, token2ValueInUsd, rateToken1ToUsd, Constants.tokenOracleDecimals
        );

        uint256 expectedValue = token2ValueInToken1;

        // Then: expectedTotalValue should be equal to actualTotalValue
        assertEq(expectedValue, actualTotalValue);
    }

    function testRevert_Fuzz_getTotalValue_CalculateValueInBaseCurrencyFromValueInUsdOverflow(
        uint256 rateToken1ToUsd,
        uint256 amountToken2,
        uint8 token2Decimals
    ) public {
        // Given: token2Decimals is less than oracleEthToUsdDecimals, rateToken1ToUsd is less than equal to max uint256 value and bigger than 0,
        // creatorAddress calls addBaseCurrency, calls addPricingModule with standardERC20PricingModule,
        // oracleOwner calls transmit with rateToken1ToUsd and rateToken2ToUsd
        vm.assume(token2Decimals < Constants.tokenOracleDecimals);
        vm.assume(rateToken1ToUsd <= uint256(type(int256).max));
        vm.assume(rateToken1ToUsd > 0);
        vm.assume(
            amountToken2
                > ((type(uint256).max / uint256(rates.token2ToUsd) / Constants.WAD) * 10 ** Constants.tokenOracleDecimals)
                    / 10 ** (Constants.tokenOracleDecimals - token2Decimals)
        );

        ArcadiaOracle oracle = initMockedOracle(0, "LINK / USD");
        vm.startPrank(users.creatorAddress);
        mockERC20.token2 = new ERC20Mock(
            "TOKEN2",
            "T2",
            token2Decimals);
        address[] memory oracleAssetToUsdArr = new address[](1);
        oracleAssetToUsdArr[0] = address(oracle);
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: 0,
                baseAsset: "ASSET",
                quoteAsset: "USD",
                oracle: address(oracle),
                baseAssetAddress: address(mockERC20.token2),
                isActive: true
            })
        );
        erc20PricingModule.addAsset(
            address(mockERC20.token2), oracleAssetToUsdArr, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsd));
        oracle.transmit(int256(rates.token2ToUsd));
        vm.stopPrank();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken2;

        // Then: getTotalValue should revert with arithmetic overflow
        vm.expectRevert(bytes(""));
        mainRegistryExtension.getTotalValue(assetAddresses, assetIds, assetAmounts, address(mockERC20.token1));
    }

    function testRevert_Fuzz_getTotalValue_CalculateValueInBaseCurrencyFromValueInUsdWithRateZero(uint256 amountToken2)
        public
    {
        vm.assume(amountToken2 > 0);

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(0));
        mockOracles.token2ToUsd.transmit(int256(rates.stable2ToUsd));
        vm.stopPrank();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken2;

        // Then: getTotalValue should revert
        vm.expectRevert(bytes(""));
        mainRegistryExtension.getTotalValue(assetAddresses, assetIds, assetAmounts, address(mockERC20.token1));
    }
}
