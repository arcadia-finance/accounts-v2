/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Fuzz_Test } from "../../Fuzz.t.sol";
import { OracleModuleMock } from "../../../utils/mocks/oracle-modules/OracleModuleMock.sol";
import { PrimaryAMMock } from "../../../utils/mocks/asset-modules/PrimaryAMMock.sol";

/**
 * @notice Common logic needed by all "AbstractPrimaryAM" fuzz tests.
 */
abstract contract AbstractPrimaryAM_Fuzz_Test is Fuzz_Test {
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

    /// forge-lint: disable-next-item(pascal-case-struct)
    struct PrimaryAMAssetState {
        address creditor;
        address asset;
        uint96 assetId;
        uint112 exposureAssetLast;
        uint112 exposureAssetMax;
        uint256 usdExposureUpperAssetToAsset;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    PrimaryAMMock internal assetModule;
    OracleModuleMock internal oracleModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.owner);
        assetModule = new PrimaryAMMock(address(registry), 0);
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function addMockedOracle(uint256 oracleId, uint256 rate, bytes16 baseAsset, bytes16 quoteAsset, bool active)
        public
    {
        oracleModule.setOracle(oracleId, baseAsset, quoteAsset, active);
        registry.setOracleToOracleModule(oracleId, address(oracleModule));
        oracleModule.setRate(oracleId, rate);
    }

    /// forge-lint: disable-next-item(mixed-case-function)
    function setPrimaryAMAssetState(PrimaryAMAssetState memory assetState) internal {
        assetModule.setExposure(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            assetState.exposureAssetLast,
            assetState.exposureAssetMax
        );

        assetModule.setUsdValue(assetState.usdExposureUpperAssetToAsset);
    }
}
