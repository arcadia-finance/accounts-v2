/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../Fuzz.t.sol";

import { AccountV1 } from "../../../AccountV1.sol";
import { ArcadiaOracle } from "../../../mockups/ArcadiaOracle.sol";

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

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();
    }

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
}
