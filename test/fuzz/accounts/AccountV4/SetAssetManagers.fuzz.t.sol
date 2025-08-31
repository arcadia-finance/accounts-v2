/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountsGuard } from "../../../../src/accounts/helpers/AccountsGuard.sol";
import { AccountV4 } from "../../../../src/accounts/AccountV4.sol";
import { AccountV4_Fuzz_Test } from "./_AccountV4.fuzz.t.sol";
import { AssetManagerMock } from "../../../utils/mocks/asset-managers/AssetManagerMock.sol";

/**
 * @notice Fuzz tests for the function "setAssetManagers" of contract "AccountV4".
 */
contract SetAssetManagers_AccountV4_Fuzz_Test is AccountV4_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AssetManagerMock internal assetManager1;
    AssetManagerMock internal assetManager2;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV4_Fuzz_Test.setUp();

        // Deploy Asset Managers.
        assetManager1 = new AssetManagerMock();
        assetManager2 = new AssetManagerMock();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_setAssetManagers_NonOwner(SetAssetManagersParams memory params, address nonOwner) public {
        // Given: Non-owner is not the owner of the account.
        vm.assume(nonOwner != users.accountOwner);

        // When: Non-owner calls "setAssetManagers" on the Account.
        // Then: Transaction should revert with AccountErrors.OnlyOwner.selector.
        vm.prank(nonOwner);
        vm.expectRevert(AccountErrors.OnlyOwner.selector);
        setAssetManagers(params);
    }

    function testFuzz_Revert_setAssetManagers_Reentered(SetAssetManagersParams memory params) public {
        // Given: Reentrancy guard is in locked state.
        accountsGuard.setAccount(address(1));

        // When: accountOwner calls "setAssetManagers" on the Account.
        // Then: Transaction should revert with AccountsGuard.OnlyReentrant.selector.
        vm.prank(users.accountOwner);
        vm.expectRevert(AccountsGuard.Reentered.selector);
        setAssetManagers(params);
    }

    function testFuzz_Revert_setAssetManagers_LengthMismatch_Statuses(TestParams memory testParams) public {
        // Given: statuses has a length that is different from operators.
        SetAssetManagersParams memory params = getParams(testParams);
        params.statuses = new bool[](1);

        // When: accountOwner calls "setAssetManagers" on the Account.
        // Then: Transaction should revert with AccountErrors.LengthMismatch.selector.
        vm.prank(users.accountOwner);
        vm.expectRevert(AccountErrors.LengthMismatch.selector);
        setAssetManagers(params);
    }

    function testFuzz_Revert_setAssetManagers_LengthMismatch_Datas(TestParams memory testParams) public {
        // Given: datas has a length that is different from operators.
        SetAssetManagersParams memory params = getParams(testParams);
        params.datas = new bytes[](1);

        // When: accountOwner calls "setAssetManagers" on the Account.
        // Then: Transaction should revert with AccountErrors.LengthMismatch.selector.
        vm.prank(users.accountOwner);
        vm.expectRevert(AccountErrors.LengthMismatch.selector);
        setAssetManagers(params);
    }

    function testFuzz_Success_setAssetManagers(TestParams memory testParams) public {
        // Given : Initial state.
        SetAssetManagersParams memory params = getParams(testParams);
        bool[] memory currentStatuses = new bool[](2);
        currentStatuses[0] = testParams.assetManagerState1.currentStatus;
        currentStatuses[1] = testParams.assetManagerState2.currentStatus;
        vm.prank(users.accountOwner);
        accountSpot.setAssetManagers(params.assetManagers, currentStatuses, new bytes[](2));

        // When: accountOwner calls "setAssetManagers" on the Account.
        // Then: Hook is called when operatorData is not empty.
        if (params.datas[0].length > 0) {
            vm.expectCall(
                address(assetManager1),
                abi.encodeWithSelector(
                    assetManager1.onSetAssetManager.selector, users.accountOwner, params.statuses[0], params.datas[0]
                )
            );
        }
        if (params.datas[1].length > 0) {
            vm.expectCall(
                address(assetManager2),
                abi.encodeWithSelector(
                    assetManager2.onSetAssetManager.selector, users.accountOwner, params.statuses[1], params.datas[1]
                )
            );
        }
        // And: Correct events are emitted.
        vm.expectEmit(address(accountSpot));
        emit AccountV4.AssetManagerSet(users.accountOwner, address(assetManager1), params.statuses[0]);
        vm.expectEmit(address(accountSpot));
        emit AccountV4.AssetManagerSet(users.accountOwner, address(assetManager2), params.statuses[1]);
        vm.prank(users.accountOwner);
        setAssetManagers(params);

        // And: Asset Managers are set.
        assertEq(accountSpot.isAssetManager(users.accountOwner, address(assetManager1)), params.statuses[0]);
        assertEq(accountSpot.isAssetManager(users.accountOwner, address(assetManager2)), params.statuses[1]);
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    struct SetAssetManagersParams {
        address[] assetManagers;
        bool[] statuses;
        bytes[] datas;
    }

    struct AssetManagerState {
        bool currentStatus;
        bool newStatus;
        bytes data;
    }

    struct TestParams {
        AssetManagerState assetManagerState1;
        AssetManagerState assetManagerState2;
    }

    function getParams(TestParams memory testParams) internal view returns (SetAssetManagersParams memory params) {
        params.assetManagers = new address[](2);
        params.assetManagers[0] = address(assetManager1);
        params.assetManagers[1] = address(assetManager2);

        params.statuses = new bool[](2);
        params.statuses[0] = testParams.assetManagerState1.newStatus;
        params.statuses[1] = testParams.assetManagerState2.newStatus;

        params.datas = new bytes[](2);
        params.datas[0] = testParams.assetManagerState1.data;
        params.datas[1] = testParams.assetManagerState2.data;
    }

    function setAssetManagers(SetAssetManagersParams memory params) internal {
        accountSpot.setAssetManagers(params.assetManagers, params.statuses, params.datas);
    }
}
