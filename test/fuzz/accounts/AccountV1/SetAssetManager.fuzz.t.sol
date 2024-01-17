/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1_Fuzz_Test, AccountErrors } from "./_AccountV1.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setAssetManager" of contract "AccountV1".
 */
contract SetAssetManager_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_setAssetManager(address assetManager, bool startValue, bool endvalue, address msgSender)
        public
    {
        vm.startPrank(msgSender);
        vm.expectEmit(true, true, true, true);
        emit AssetManagerSet(msgSender, assetManager, startValue);
        accountExtension.setAssetManager(assetManager, startValue);
        vm.stopPrank();
        assertEq(accountExtension.isAssetManager(msgSender, assetManager), startValue);

        vm.startPrank(msgSender);
        vm.expectEmit(true, true, true, true);
        emit AssetManagerSet(msgSender, assetManager, endvalue);
        accountExtension.setAssetManager(assetManager, endvalue);
        vm.stopPrank();
        assertEq(accountExtension.isAssetManager(msgSender, assetManager), endvalue);
    }
}
