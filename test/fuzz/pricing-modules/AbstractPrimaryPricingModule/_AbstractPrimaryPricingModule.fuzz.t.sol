/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { OracleModuleMock } from "../../../utils/mocks/OracleModuleMock.sol";

import { PrimaryPricingModuleMock } from "../../../utils/mocks/PrimaryPricingModuleMock.sol";

/**
 * @notice Common logic needed by all "AbstractPrimaryPricingModule" fuzz tests.
 */
abstract contract AbstractPrimaryPricingModule_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              CONSTANTS
    /////////////////////////////////////////////////////////////// */

    uint256 internal constant INT256_MAX = 2 ** 255 - 1;
    // While the true minimum value of an int256 is 2 ** 255, Solidity overflows on a negation (since INT256_MAX is one less).
    // -> This true minimum value will overflow and revert.
    uint256 internal constant INT256_MIN = 2 ** 255 - 1;

    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct PrimaryPricingModuleAssetState {
        address creditor;
        address asset;
        uint96 assetId;
        uint128 exposureAssetLast;
        uint128 exposureAssetMax;
        uint256 usdExposureUpperAssetToAsset;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    PrimaryPricingModuleMock internal pricingModule;
    OracleModuleMock internal oracleModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        pricingModule = new PrimaryPricingModuleMock(address(mainRegistryExtension), 0);
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

    function setPrimaryPricingModuleAssetState(PrimaryPricingModuleAssetState memory assetState) internal {
        pricingModule.setExposure(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            assetState.exposureAssetLast,
            assetState.exposureAssetMax
        );

        pricingModule.setUsdValue(assetState.usdExposureUpperAssetToAsset);
    }
}
