/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountsGuard } from "../../../../src/accounts/helpers/AccountsGuard.sol";
import { AccountV4 } from "../../../../src/accounts/AccountV4.sol";
import { AccountV4_Fuzz_Test } from "./_AccountV4.fuzz.t.sol";
import { AssetManagerMock } from "../../../utils/mocks/asset-managers/AssetManagerMock.sol";

/**
 * @notice Fuzz tests for the function "removeAssetManager" of contract "AccountV4".
 */
contract RemoveAssetManager_AccountV4_Fuzz_Test is AccountV4_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AssetManagerMock internal assetManager;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV4_Fuzz_Test.setUp();

        // Deploy Asset Managers.
        assetManager = new AssetManagerMock();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_removeAssetManager_Reentered(address msgSender, address assetManager_) public {
        // Given: Reentrancy guard is in locked state.
        accountsGuard.setAccount(address(1));

        // When: msgSender calls "removeAssetManager" on the Account.
        // Then: Transaction should revert with AccountsGuard.Reentered.selector.
        vm.prank(msgSender);
        vm.expectRevert(AccountsGuard.Reentered.selector);
        accountSpot.removeAssetManager(assetManager_);
    }

    function testFuzz_Success_removeAssetManager(address msgSender, bool currentStatus) public {
        // Given : Initial state.
        address[] memory assetManagers = new address[](1);
        assetManagers[0] = address(assetManager);
        bool[] memory currentStatuses = new bool[](1);
        currentStatuses[0] = currentStatus;
        vm.prank(users.accountOwner);
        accountSpot.setAssetManagers(assetManagers, currentStatuses, new bytes[](1));

        // When: msgSender calls "removeAssetManager" on the Account.
        // Then: Correct events are emitted.
        vm.expectEmit(address(accountSpot));
        emit AccountV4.AssetManagerSet(msgSender, address(assetManager), false);
        vm.prank(msgSender);
        accountSpot.removeAssetManager(address(assetManager));

        // And: Asset Managers are set.
        assertFalse(accountSpot.isAssetManager(msgSender, address(assetManager)));
    }
}
