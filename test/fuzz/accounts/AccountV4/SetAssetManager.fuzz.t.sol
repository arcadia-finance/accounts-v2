/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountV4 } from "../../../../src/accounts/AccountV4.sol";
import { AccountV4_Fuzz_Test } from "./_AccountV4.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setAssetManager" of contract "AccountV4".
 */
contract SetAssetManager_AccountV4_Fuzz_Test is AccountV4_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV4_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_setAssetManager(address assetManager, bool startValue, bool endvalue, address msgSender)
        public
    {
        vm.startPrank(msgSender);
        vm.expectEmit(true, true, true, true);
        emit AccountV4.AssetManagerSet(msgSender, assetManager, startValue);
        accountSpot.setAssetManager(assetManager, startValue);
        vm.stopPrank();
        assertEq(accountSpot.isAssetManager(msgSender, assetManager), startValue);

        vm.startPrank(msgSender);
        vm.expectEmit(true, true, true, true);
        emit AccountV4.AssetManagerSet(msgSender, assetManager, endvalue);
        accountSpot.setAssetManager(assetManager, endvalue);
        vm.stopPrank();
        assertEq(accountSpot.isAssetManager(msgSender, assetManager), endvalue);
    }
}
