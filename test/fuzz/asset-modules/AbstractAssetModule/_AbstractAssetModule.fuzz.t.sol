/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { AssetModuleMock } from "../../../utils/mocks/AssetModuleMock.sol";

/**
 * @notice Common logic needed by all "AbstractAssetModule" fuzz tests.
 */
abstract contract AbstractAssetModule_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AssetModuleMock internal assetModule;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */
    error Only_Registry();
    error Risk_Factor_Not_In_Limits();
    error Overflow();
    error Oracle_Still_Active();
    error Bad_Oracle_Sequence();
    error Coll_Factor_Not_In_Limits();
    error Liq_Factor_Not_In_Limits();
    error Exposure_Not_In_Limits();
    error Invalid_Range();
    error Invalid_Id();
    error Asset_Not_Allowed();
    error Asset_Already_In_AM();

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        assetModule = new AssetModuleMock(address(registryExtension), 0);
    }
}
