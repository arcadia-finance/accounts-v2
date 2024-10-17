/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountSpot } from "../../../../src/accounts/AccountSpot.sol";
import { AccountSpot_Fuzz_Test } from "./_AccountSpot.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setAssetManager" of contract "AccountSpot".
 */
contract SetAssetManager_AccountSpot_Fuzz_Test is AccountSpot_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountSpot_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_setAssetManager(address assetManager, bool startValue, bool endvalue, address msgSender)
        public
    {
        vm.startPrank(msgSender);
        vm.expectEmit(true, true, true, true);
        emit AccountSpot.AssetManagerSet(msgSender, assetManager, startValue);
        accountSpot.setAssetManager(assetManager, startValue);
        vm.stopPrank();
        assertEq(accountSpot.isAssetManager(msgSender, assetManager), startValue);

        vm.startPrank(msgSender);
        vm.expectEmit(true, true, true, true);
        emit AccountSpot.AssetManagerSet(msgSender, assetManager, endvalue);
        accountSpot.setAssetManager(assetManager, endvalue);
        vm.stopPrank();
        assertEq(accountSpot.isAssetManager(msgSender, assetManager), endvalue);
    }
}
