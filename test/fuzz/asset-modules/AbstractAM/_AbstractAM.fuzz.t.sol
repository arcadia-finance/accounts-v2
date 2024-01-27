/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { AssetModuleMock } from "../../../utils/mocks/asset-modules/AssetModuleMock.sol";

/**
 * @notice Common logic needed by all "AbstractAssetModule" fuzz tests.
 */
abstract contract AbstractAM_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AssetModuleMock internal assetModule;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */
    error OnlyRegistry();
    error RiskFactorNotInLimits();
    error Overflow();
    error OracleStillActive();
    error BadOracleSequence();
    error CollFactorNotInLimits();
    error LiqFactorNotInLimits();
    error ExposureNotInLimits();
    error InvalidRange();
    error InvalidId();
    error AssetNotAllowed();
    error AssetAlreadyInAM();

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        assetModule = new AssetModuleMock(address(registryExtension), 0);
    }
}
