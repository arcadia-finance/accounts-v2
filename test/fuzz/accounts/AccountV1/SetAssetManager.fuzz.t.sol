/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "setAssetManager" of contract "AccountV1".
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
    function testFuzz_Revert_setAssetManager_NonOwner(address nonOwner, address assetManager, bool value) public {
        vm.assume(nonOwner != users.accountOwner);

        vm.startPrank(nonOwner);
        vm.expectRevert("A: Only Owner");
        accountExtension.setAssetManager(assetManager, value);
        vm.stopPrank();
    }

    function testFuzz_Success_setAssetManager(address assetManager, bool startValue, bool endvalue) public {
        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit AssetManagerSet(users.accountOwner, assetManager, startValue);
        accountExtension.setAssetManager(assetManager, startValue);
        vm.stopPrank();
        assertEq(accountExtension.isAssetManager(users.accountOwner, assetManager), startValue);

        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit AssetManagerSet(users.accountOwner, assetManager, endvalue);
        accountExtension.setAssetManager(assetManager, endvalue);
        vm.stopPrank();
        assertEq(accountExtension.isAssetManager(users.accountOwner, assetManager), endvalue);
    }
}
