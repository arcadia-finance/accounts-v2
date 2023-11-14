/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../Fuzz.t.sol";

import { ArcadiaOracle } from "../../utils/mocks/ArcadiaOracle.sol";
import { DerivedPricingModuleMock } from "../../utils/mocks/DerivedPricingModuleMock.sol";
import { OracleModuleMock } from "../../utils/mocks/OracleModuleMock.sol";
import { PrimaryPricingModuleMock } from "../../utils/mocks/PrimaryPricingModuleMock.sol";

/**
 * @notice Common logic needed by all "MainRegistry" fuzz tests.
 */
abstract contract MainRegistry_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    PrimaryPricingModuleMock internal primaryPricingModule;
    DerivedPricingModuleMock internal derivedPricingModule;

    OracleModuleMock internal oracleModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);
        primaryPricingModule = new PrimaryPricingModuleMock(address(mainRegistryExtension), 0);
        mainRegistryExtension.addPricingModule(address(primaryPricingModule));

        derivedPricingModule = new DerivedPricingModuleMock(address(mainRegistryExtension), 0);
        mainRegistryExtension.addPricingModule(address(derivedPricingModule));
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                         HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function addMockedOracle(uint256 oracleId, uint256 rate, bytes16 baseAsset, bytes16 quoteAsset, bool active)
        public
    {
        oracleModule.setOracle(oracleId, baseAsset, quoteAsset, active);
        mainRegistryExtension.setOracleToOracleModule(oracleId, address(oracleModule));
        oracleModule.setRate(oracleId, rate);
    }

    function convertAssetToUsd(uint256 assetDecimals, uint256 amount, uint80[] memory oracleArr)
        public
        view
        returns (uint256 usdValue)
    {
        uint256 ratesMultiplied = 1;
        uint256 sumOfOracleDecimals;
        for (uint8 i; i < oracleArr.length; i++) {
            (,, address oracle) = chainlinkOM.getOracleInformation(oracleArr[i]);
            (, int256 answer,,,) = ArcadiaOracle(oracle).latestRoundData();
            ratesMultiplied *= uint256(answer);
            sumOfOracleDecimals += ArcadiaOracle(oracle).decimals();
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
}
