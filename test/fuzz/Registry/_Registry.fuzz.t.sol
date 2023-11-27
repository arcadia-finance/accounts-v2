/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../Fuzz.t.sol";

import { ArcadiaOracle } from "../../utils/mocks/ArcadiaOracle.sol";
import { DerivedAssetModuleMock } from "../../utils/mocks/DerivedAssetModuleMock.sol";
import { OracleModuleMock } from "../../utils/mocks/OracleModuleMock.sol";
import { PrimaryAssetModuleMock } from "../../utils/mocks/PrimaryAssetModuleMock.sol";
import { RegistryErrors } from "../../../src/Registry.sol";

/**
 * @notice Common logic needed by all "Registry" fuzz tests.
 */
abstract contract Registry_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    PrimaryAssetModuleMock internal primaryAssetModule;
    DerivedAssetModuleMock internal derivedAssetModule;

    OracleModuleMock internal oracleModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);
        primaryAssetModule = new PrimaryAssetModuleMock(address(registryExtension), 0);
        registryExtension.addAssetModule(address(primaryAssetModule));

        derivedAssetModule = new DerivedAssetModuleMock(address(registryExtension), 0);
        registryExtension.addAssetModule(address(derivedAssetModule));
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                         HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function addMockedOracle(uint256 oracleId, uint256 rate, bytes16 baseAsset, bytes16 quoteAsset, bool active)
        public
    {
        oracleModule.setOracle(oracleId, baseAsset, quoteAsset, active);
        registryExtension.setOracleToOracleModule(oracleId, address(oracleModule));
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

    function convertUsdToNumeraire(
        uint256 numeraireDecimals,
        uint256 usdAmount,
        uint256 rateNumeraireToUsd,
        uint256 oracleDecimals
    ) public pure returns (uint256 assetValue) {
        assetValue = (usdAmount * 10 ** oracleDecimals) / rateNumeraireToUsd;
        // USD value will always be in 18 decimals so we have to convert to numeraire decimals if needed
        if (numeraireDecimals < 18) {
            assetValue /= 10 ** (18 - numeraireDecimals);
        }
    }
}
