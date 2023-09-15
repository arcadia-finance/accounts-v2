/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, MainRegistry_Fuzz_Test } from "./_MainRegistry.fuzz.t.sol";

import { ArcadiaOracle } from "../../../mockups/ArcadiaOracle.sol";
import { ERC20Mock } from "../../../mockups/ERC20SolmateMock.sol";
import { OracleHub } from "../../../OracleHub.sol";

/**
 * @notice Fuzz tests for the "getTotalValue" of contract "MainRegistry".
 */
contract GetTotalValue_MainRegistry_Fuzz_Test is MainRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MainRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getTotalValue_UnknownBaseCurrency(address basecurrency) public {
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

    function testFuzz_Revert_getTotalValue_CalculateValueInBaseCurrencyFromValueInUsdOverflow(
        uint256 rateToken1ToUsd,
        uint256 amountToken2,
        uint8 token2Decimals
    ) public {
        // Given: token2Decimals is less than tokenOracleDecimals, rateToken1ToUsd is less than equal to max uint256 value and bigger than 0,
        // creatorAddress calls addBaseCurrency, calls addPricingModule with standardERC20PricingModule,
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
            OracleHub.OracleInformation({
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

    function testFuzz_Revert_getTotalValue_CalculateValueInBaseCurrencyFromValueInUsdWithRateZero(uint256 amountToken2)
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

    function testFuzz_Success_getTotalValue() public {
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

    function testFuzz_Success_getTotalValue_CalculateValueInBaseCurrencyFromValueInUsd_token2With18Decimals(
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

    function testFuzz_Success_getTotalValue_CalculateValueInBaseCurrencyFromValueInUsd_token2With6decimals(
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
}
